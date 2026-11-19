#------------ Load in packages, expression data, nichenets ligand-target matrix and gene sets of interest -------------

# packages

library(nichenetr)
library(tidyverse)
library(RColorBrewer)

# additional functions applications
source("scripts/functions_applications.R")

# expression data
hnscc_expression = readRDS("data/hnscc_expression")
expression = hnscc_expression$expression
sample_info = hnscc_expression$sample_info

tumors_remove = c("HN10","HN","HN12", "HN13", "HN24", "HN7", "HN8","HN23")

fibroblast_ids = sample_info %>% filter(`Lymph node` == 0) %>% filter((tumor %in% tumors_remove == FALSE)) %>% filter(`non-cancer cell type` == "CAF") %>% .$cell
cancer_ids = sample_info %>% filter(`Lymph node` == 0) %>% filter(`classified  as cancer cell` == 1) %>% filter((tumor %in% tumors_remove == FALSE)) %>% .$cell

expressed_genes_fibroblasts = expression[fibroblast_ids,] %>% apply(2,function(x){10*(2**x - 1)}) %>% apply(2,function(x){log2(mean(x) + 1)}) %>% .[. >= 4] %>% names()
expressed_genes_cancer = expression[cancer_ids,] %>% apply(2,function(x){10*(2**x - 1)}) %>% apply(2,function(x){log2(mean(x) + 1)}) %>% .[. >= 4] %>% names()

# ligand-target matrix of nichenet
ligand_target_matrix = readRDS("../../evaluation/ligand_target_matrix")

# gene sets of interest
pemt_genes = read_tsv("data/gene_signature_pemt.txt", col_names = "gene") %>% .$gene %>% .[. %in% rownames(ligand_target_matrix)]
background_expressed_genes = expressed_genes_cancer %>% .[. %in% rownames(ligand_target_matrix)]

#------------ NicheNet analysis: gene set upstream regulator analysis -------------
# infer ligands expressed by fibroblasts and receptors expressed by cancer cells
lr_network = readRDS("../../networks/data/ligand_receptor/lr_network") 
ligands = lr_network$from %>% unique()
expressed_ligands = intersect(ligands,expressed_genes_fibroblasts)
receptors = lr_network$to %>% unique()
expressed_receptors = intersect(receptors,expressed_genes_cancer)
expressed_ligands = lr_network %>% filter(from %in% expressed_ligands & to %in% expressed_receptors) %>% .$from %>% unique()

# infer ligand activity in predicting pemt vs background_expressed_genes
setting_pemt = lapply(list(pemt_genes), convert_gene_list_settings_evaluation, name = "pemt", ligands_oi = expressed_ligands, background = background_expressed_genes)
settings_ligand_pred = convert_settings_ligand_prediction(setting_pemt, all_ligands = expressed_ligands, validation = FALSE, single = TRUE)
ligand_importances_bg_expr = bind_rows(lapply(settings_ligand_pred, get_single_ligand_importances,ligand_target_matrix, known = FALSE))

# interpret and save results
ligand_importances_bg_expr %>% arrange(-pearson) 
saveRDS(ligand_importances_bg_expr, "results/ligand_importance_pemt_signature")

#------------ multi-ligand target gene prediction: rf-feature selection to determine ligand activity --------------

## infer ligand activity in predicting pemt vs background_expressed_genes: random forest variable importances
own_rf_imps = setting_pemt %>% lapply(get_multi_ligand_rf_importances,ligand_target_matrix, mtry = 3, known = FALSE) %>% .[[1]]
own_rf_imps %>% saveRDS("results/pemt_multi_ligand_own_rf_imps")
### write importances out to excel files

ligand_importances_bg_expr = readRDS("results/ligand_importance_pemt_signature")
ligand_importances_bg_expr %>% as.data.frame() %>% xlsx::write.xlsx2("results/ligand_importances_pemt_signature.xlsx", sheetName="single_ligand_imps",col.names=TRUE, row.names=FALSE, append=FALSE)

own_rf_imps = readRDS("results/pemt_multi_ligand_own_rf_imps")
own_rf_imps %>% as.data.frame() %>% xlsx::write.xlsx2("results/ligand_importances_pemt_signature.xlsx", sheetName="multi_ligand_rf_imps",col.names=TRUE, row.names=FALSE, append=TRUE)
own_rf_imps %>% arrange(-MeanDecreaseGini)

##------------ multi-ligand target gene prediction: get an idea of how well all ligands can explain p-EMT gene signature  --------------
# 5 rounds of 5-fold CV of p-EMT genes
############################## look at all potential ligands

k = 5 # 5-fold
n = 5 # 5 rounds

pemt_gene_predictions_all_list = seq(n) %>% lapply(assess_rf_class_probabilities,k, pemt_genes,background_expressed_genes,expressed_ligands,ligand_target_matrix)
saveRDS(pemt_gene_predictions_all_list,"results/multi_ligand_prediction_rf_all_ligands_5x5cv")

# pemt_gene_predictions_all_list_k2 = seq(n) %>% lapply(assess_rf_class_probabilities,2, pemt_genes,background_expressed_genes,expressed_ligands,ligand_target_matrix)
# target_prediction_performances_cv_k2 = pemt_gene_predictions_all_list_k2 %>% lapply(classification_evaluation_continuous_pred_wrapper) %>% bind_rows() %>% mutate(round=seq(1:nrow(.)))
# target_prediction_performances_cv_k2$auroc %>% mean()

pemt_gene_predictions_all_list = readRDS("results/multi_ligand_prediction_rf_all_ligands_5x5cv")

# get performance: auroc-aupr
target_prediction_performances_cv = pemt_gene_predictions_all_list %>% lapply(classification_evaluation_continuous_pred_wrapper) %>% bind_rows() %>% mutate(round=seq(1:nrow(.)))
xlsx::write.xlsx2(target_prediction_performances_cv %>% as.data.frame(), "results/performances_multi_ligand_prediction_rf_5x5cv.xlsx", sheetName="all_ligands_rf_cv_performances",col.names=TRUE, row.names=FALSE, append=FALSE)

target_prediction_performances_cv$auroc %>% mean()
# 0.7263084
target_prediction_performances_cv$auroc %>% sd()
# 0.01008072

target_prediction_performances_cv$aupr %>% mean()
# 0.07264616
target_prediction_performances_cv$aupr %>% sd()
# 0.004561015

target_prediction_performances_cv$pearson %>% mean()
# 0.1670924
target_prediction_performances_cv$pearson %>% sd()
# 0.008137189

target_prediction_performances_cv$pearson_log_pval %>% mean()


# get performance: how many p-EMT genes and non-p-EMT-genes among top 5% predicted targets
target_prediction_performances_discrete_cv = pemt_gene_predictions_all_list %>% lapply(calculate_fraction_top_predicted) %>% bind_rows() %>% ungroup() %>% mutate(round=rep(1:length(pemt_gene_predictions_all_list), each = 2))

target_prediction_performances_discrete_cv %>% filter(response) %>% .$fraction_positive_predicted %>% mean()
# 0.28125
target_prediction_performances_discrete_cv %>% filter(!response) %>% .$fraction_positive_predicted %>% mean()
# 0.04692102

# get top predicted genes
top_predicted_genes = seq(length(pemt_gene_predictions_all_list))  %>% lapply(get_top_predicted_genes,pemt_gene_predictions_all_list) %>% reduce(full_join, by = c("gene","true_target"))


# to demonstrate why we used RF: compare to performance obtained via other classification algorithms
# rf_pred = setting_pemt %>% lapply(evaluate_multi_ligand_target_prediction,ligand_target_matrix, algorithm = "rf",var_imps = FALSE, cv_number = 5, cv_repeats = 5) %>% .[[1]]
# lda_pred = setting_pemt %>% lapply(evaluate_multi_ligand_target_prediction,ligand_target_matrix, algorithm = "lda",var_imps = FALSE, cv_number = 5, cv_repeats = 5) %>% .[[1]]
# glm_pred = setting_pemt %>% lapply(evaluate_multi_ligand_target_prediction,ligand_target_matrix, algorithm = "glm",var_imps = FALSE, cv_number = 5, cv_repeats = 5) %>% .[[1]]
# tree_pred = setting_pemt %>% lapply(evaluate_multi_ligand_target_prediction,ligand_target_matrix, algorithm = "C5.0",var_imps = FALSE, cv_number = 5, cv_repeats = 5) %>% .[[1]]
# nb_pred = setting_pemt %>% lapply(evaluate_multi_ligand_target_prediction,ligand_target_matrix, algorithm = "naive_bayes",var_imps = FALSE, cv_number = 5, cv_repeats = 5) %>% .[[1]]
# nnet_pred = setting_pemt %>% lapply(evaluate_multi_ligand_target_prediction,ligand_target_matrix, algorithm = "nnet",var_imps = FALSE, cv_number = 5, cv_repeats = 5) %>% .[[1]]
# pls_pred = setting_pemt %>% lapply(evaluate_multi_ligand_target_prediction,ligand_target_matrix, algorithm = "pls",var_imps = FALSE, cv_number = 5, cv_repeats = 5) %>% .[[1]]
# 
# list(rf_pred = rf_pred,
#      lda_pred = lda_pred,
#      glm_pred = glm_pred,
#      tree_pred = tree_pred,
#      nb_pred = nb_pred,
#      nnet_pred = nnet_pred,
#      pls_pred = pls_pred) %>% saveRDS("results/caret_multi_ligand")

caret_multi_ligand = readRDS("results/caret_multi_ligand")
caret_multi_ligand$rf_pred$performances$auroc %>% mean()
# 0.7414634
caret_multi_ligand$lda_pred$performances$auroc %>% mean()
# 0.7393782
caret_multi_ligand$glm_pred$performances$auroc %>% mean()
# 0.7257372
caret_multi_ligand$tree_pred$performances$auroc %>% mean()
# 0.5
caret_multi_ligand$nb_pred$performances$auroc %>% mean()
# 0.6886474
caret_multi_ligand$nnet_pred$performances$auroc %>% mean()
# 0.4863831
caret_multi_ligand$pls_pred$performances$auroc %>% mean()
# 0.3172435 --> 0.683

caret_multi_ligand$rf_pred$performances$pearson %>% mean()
# 0.1639751
caret_multi_ligand$lda_pred$performances$pearson %>% mean()
# 0.1229582
caret_multi_ligand$glm_pred$performances$pearson %>% mean()
# 0.1542111
caret_multi_ligand$tree_pred$performances$pearson %>% mean()
# NA
caret_multi_ligand$nb_pred$performances$pearson %>% mean()
# 0.09018354
caret_multi_ligand$nnet_pred$performances$pearson %>% mean()
# NA
caret_multi_ligand$pls_pred$performances$pearson %>% mean()
# -0.09598687 --> 0.09598687
############################## look only at top20 ligands now (according to PCC)

ligand_importances_bg_expr = readRDS("results/ligand_importance_pemt_signature")
best_upstream_ligands = ligand_importances_bg_expr %>% top_n(20, pearson) %>% arrange(-pearson) %>% .$test_ligand

k = 5 # 5-fold
n = 5 # 5 rounds

pemt_gene_predictions_top20_list = seq(n) %>% lapply(assess_rf_class_probabilities,k, pemt_genes,background_expressed_genes,best_upstream_ligands,ligand_target_matrix)
saveRDS(pemt_gene_predictions_top20_list,"results/multi_ligand_prediction_rf_top20_ligands_5x5cv")

pemt_gene_predictions_top20_list = readRDS("results/multi_ligand_prediction_rf_top20_ligands_5x5cv")

# get performance: auroc-aupr
target_prediction_performances_cv = pemt_gene_predictions_top20_list %>% lapply(classification_evaluation_continuous_pred_wrapper) %>% bind_rows() %>% mutate(round=seq(1:nrow(.)))
xlsx::write.xlsx2(target_prediction_performances_cv %>% as.data.frame(), "results/performances_multi_ligand_prediction_rf_5x5cv.xlsx", sheetName="top20_ligands_rf_cv_performances",col.names=TRUE, row.names=FALSE, append=TRUE)

target_prediction_performances_cv$auroc %>% mean()
# [1] 0.7447585
target_prediction_performances_cv$auroc %>% sd()
# [1] 0.008744571
target_prediction_performances_cv$aupr %>% mean()
# [1] 0.08065117
target_prediction_performances_cv$aupr %>% sd()
# [1] 0.006227352
target_prediction_performances_cv$pearson %>% mean()
# [1] 0.1762311
target_prediction_performances_cv$pearson %>% sd()
# [1] 0.006301782

# get performance: how many p-EMT genes and non-p-EMT-genes among top 5% predicted targets
target_prediction_performances_discrete_cv = pemt_gene_predictions_top20_list %>% lapply(calculate_fraction_top_predicted) %>% bind_rows() %>% ungroup() %>% mutate(round=rep(1:length(pemt_gene_predictions_top20_list), each = 2))
xlsx::write.xlsx2(target_prediction_performances_discrete_cv %>% as.data.frame(), "results/performances_multi_ligand_prediction_rf_5x5cv.xlsx", sheetName="discrete_top20_ligands_rf_cv_performances",col.names=TRUE, row.names=FALSE, append=TRUE)

target_prediction_performances_discrete_cv %>% filter(response) %>% .$fraction_positive_predicted %>% mean()
# 0.2520833
target_prediction_performances_discrete_cv %>% filter(!response) %>% .$fraction_positive_predicted %>% mean()
# 0.04742303

target_prediction_performances_discrete_fisher = pemt_gene_predictions_top20_list %>% lapply(calculate_fraction_top_predicted_fisher) 
target_prediction_performances_discrete_fisher %>% unlist() %>% mean()
# 2.53639e-10

# get top predicted genes
top_predicted_genes = seq(length(pemt_gene_predictions_top20_list))  %>% lapply(get_top_predicted_genes,pemt_gene_predictions_top20_list) %>% reduce(full_join, by = c("gene","true_target"))
xlsx::write.xlsx2(top_predicted_genes %>% as.data.frame(), "results/performances_multi_ligand_prediction_rf_5x5cv.xlsx", sheetName="top20_ligands_rf_top5%_predicted_targets",col.names=TRUE, row.names=FALSE, append=TRUE)

# write out complete fisher exact output
target_prediction_performances_discrete_fisher_complete_output = pemt_gene_predictions_top20_list %>% lapply(calculate_fraction_top_predicted_fisher_complete_output) 
xlsx::write.xlsx2(target_prediction_performances_discrete_fisher_complete_output %>% lapply(process_fisher_output) %>% bind_rows() %>% mutate(round = seq(5)) %>% as.data.frame(), "results/performances_multi_ligand_prediction_rf_5x5cv.xlsx", sheetName="fisher_output",col.names=TRUE, row.names=FALSE, append=TRUE)

# to demonstrate why we used RF: compare to performance obtained via other classification algorithms
setting_pemt = lapply(list(pemt_genes), convert_gene_list_settings_evaluation, name = "pemt", ligands_oi = best_upstream_ligands, background = background_expressed_genes)
rf_pred = setting_pemt %>% lapply(evaluate_multi_ligand_target_prediction,ligand_target_matrix, algorithm = "rf",var_imps = FALSE, cv_number = 5, cv_repeats = 5) %>% .[[1]]
lda_pred = setting_pemt %>% lapply(evaluate_multi_ligand_target_prediction,ligand_target_matrix, algorithm = "lda",var_imps = FALSE, cv_number = 5, cv_repeats = 5) %>% .[[1]]
glm_pred = setting_pemt %>% lapply(evaluate_multi_ligand_target_prediction,ligand_target_matrix, algorithm = "glm",var_imps = FALSE, cv_number = 5, cv_repeats = 5) %>% .[[1]]
nb_pred = setting_pemt %>% lapply(evaluate_multi_ligand_target_prediction,ligand_target_matrix, algorithm = "naive_bayes",var_imps = FALSE, cv_number = 5, cv_repeats = 5) %>% .[[1]]
pls_pred = setting_pemt %>% lapply(evaluate_multi_ligand_target_prediction,ligand_target_matrix, algorithm = "pls",var_imps = FALSE, cv_number = 5, cv_repeats = 5) %>% .[[1]]
# 
list(rf_pred = rf_pred,
     lda_pred = lda_pred,
     glm_pred = glm_pred,
     nb_pred = nb_pred,
     pls_pred = pls_pred) %>% saveRDS("results/caret_multi_ligand_top20")

caret_multi_ligand = readRDS("results/caret_multi_ligand_top20")
caret_multi_ligand$rf_pred$performances$auroc %>% mean()
# 0.7356895
caret_multi_ligand$lda_pred$performances$auroc %>% mean()
# 0.6375376
caret_multi_ligand$glm_pred$performances$auroc %>% mean()
# 0.6707573
caret_multi_ligand$nb_pred$performances$auroc %>% mean()
# 0.7293621
caret_multi_ligand$pls_pred$performances$auroc %>% mean()
# 0.3680287 --> 0.6319713

caret_multi_ligand$rf_pred$performances$pearson %>% mean()
# 0.1607867
caret_multi_ligand$lda_pred$performances$pearson %>% mean()
# 0.08663137
caret_multi_ligand$glm_pred$performances$pearson %>% mean()
# 0.08351902
caret_multi_ligand$nb_pred$performances$pearson %>% mean()
# 0.1357838
caret_multi_ligand$pls_pred$performances$pearson %>% mean()
# -0.03884745 --> 0.03884745

#------------------------  Ligand - target heatmap ------------------------- 

# # get list of well-predicted targets
pemt_gene_predictions_top20_list = readRDS("results/multi_ligand_prediction_rf_top20_ligands_5x5cv")
top_predicted_genes = seq(length(pemt_gene_predictions_top20_list))  %>% lapply(get_top_predicted_genes,pemt_gene_predictions_top20_list) %>% reduce(full_join, by = c("gene","true_target"))
well_predicted_targets = top_predicted_genes %>% filter(true_target) %>% pull(gene)

# read in importances (if split up analysis before and after this point)
ligand_importances_bg_expr = readRDS("results/ligand_importance_pemt_signature")

# visualize unnormalized ligand-target scores
ordered_ligands = ligand_importances_bg_expr %>% arrange(-pearson) %>% .$test_ligand
ligand_target_matrix_oi = ligand_target_matrix[background_expressed_genes,ordered_ligands]
pheatmap::pheatmap(ligand_target_matrix_oi[pemt_genes,] %>% t(),cluster_rows = FALSE)

# visualize normalized ligand-target scores: see only minor enrichment top ligands
scaled_ligand_target_matrix = ligand_target_matrix_oi %>% dynutils::scale_quantile(outlier_cutoff = 0.0005) # top and bottom outlier scores set to 1 and 0
pheatmap::pheatmap(scaled_ligand_target_matrix[pemt_genes,] %>% t(),cluster_rows = FALSE)
# hist(scaled_ligand_target_matrix)
scaled_ligand_target_matrix = ligand_target_matrix_oi %>% dynutils::scale_minmax() # top and bottom outlier scores set to 1 and 0
pheatmap::pheatmap(scaled_ligand_target_matrix[pemt_genes,] %>% t(),cluster_rows = FALSE)
# hist(scaled_ligand_target_matrix)

scaled_ligand_target_matrix = ligand_target_matrix_oi %>% scaling_zscore() # top and bottom outlier scores set to 1 and 0
pheatmap::pheatmap(scaled_ligand_target_matrix[pemt_genes,] %>% t(),cluster_rows = FALSE)

# -------------------------------- cut off target gene scores: cutoff = 0.25 quantile of top-ranked inferred ligand-target link scores --------------------------------

# show histogram of ligand activity scores
p_hist_lig_activity = ggplot(ligand_importances_bg_expr, aes(x=pearson)) + 
  geom_histogram(color="black", fill="darkorange")  + 
  # geom_density(alpha=.1, fill="orange") +
  geom_vline(aes(xintercept=min(ligand_importances_bg_expr %>% top_n(20, pearson) %>% pull(pearson))), color="red", linetype="dashed", size=1) + 
  labs(x="ligand activity (PCC)", y = "# ligands") +
  theme_classic()
p_hist_lig_activity

dev.off()
png("results/hist_lig_activity.png",width = 500, height = 250)
p_hist_lig_activity
dev.off()

## prepare for visualization: only consider top20 of ligands
best_upstream_ligands = ligand_importances_bg_expr %>% top_n(20, pearson) %>% arrange(-pearson) %>% .$test_ligand

# ligand-target matrix of nichenet
ligand_target_matrix = readRDS("../../evaluation/ligand_target_matrix")

# get the intersect of the top250 targets of the best upstream ligands and the p-EMT gene set to define possible active ligand-target links
best_upstream_ligands_ligand_target_matrix = lapply(best_upstream_ligands, get_weighted_ligand_target_links, pemt_genes, ligand_target_matrix) %>% bind_rows() 

# define a cutoff on the ligand-target links
cutoff_include_all_ligands = best_upstream_ligands_ligand_target_matrix$weight %>% quantile(0.25)

# give a score of 0 to ligand-target links not higher than the defined cutoff
ligand_target_matrix_oi = ligand_target_matrix
ligand_target_matrix_oi[ligand_target_matrix_oi < cutoff_include_all_ligands] = 0

# consider only targets belonging to the top250 targets of individual ligands and with at least one ligand-link with score higher than the defined cutoff
ligand_target_vis = ligand_target_matrix_oi[best_upstream_ligands_ligand_target_matrix$target %>% unique(),best_upstream_ligands]
ligand_target_vis_filtered = ligand_target_vis[ligand_target_vis %>% apply(1,sum) > 0,]
# ligand_target_vis_filtered = ligand_target_vis[ligand_target_vis %>% apply(1,sum) > 0,ligand_target_vis %>% apply(2,sum) > 0]

pheatmap::pheatmap(ligand_target_vis_filtered %>% t())

# save the well-predicted ligands and ligand-target links
well_predicted_targets = rownames(ligand_target_vis_filtered) 
saveRDS(well_predicted_targets,"results/well_predicted_pemt_genes_k2")

ligand_target_df = ligand_target_vis_filtered %>% data.frame() %>% rownames_to_column("target") %>% tbl_df() %>% gather("ligand","score",PTHLH:CXCL2) %>% select(ligand,target,score) %>% filter(score > 0)
saveRDS(ligand_target_df,"results/ligand_target_df_k2")

#------------ Define the ligand-receptor network of the top ligands  -------------

lr_network_top = lr_network %>% filter(from %in% best_upstream_ligands & to %in% expressed_receptors) %>% distinct(from,to)
best_upstream_receptors = lr_network_top %>% distinct(to) %>% pull(to)

#------------ Prepare figures: ligand-target network heatmap  -------------

distoi = dist(1-cor(t(ligand_target_vis_filtered)))
hclust_obj = hclust(distoi, method = "ward.D2")
order_targets = hclust_obj$labels[hclust_obj$order]

# distoi_ligands = dist(1-cor(ligand_target_vis_filtered))
# hclust_obj = hclust(distoi_ligands, method = "ward.D2")
# order_ligands = hclust_obj$labels[hclust_obj$order]

order_ligands = rev(best_upstream_ligands)  %>% make.names() %>% intersect(colnames(ligand_target_vis_filtered)) # dont make use of hierarchical clustering for order

vis_ligand_target_network = ligand_target_vis_filtered[order_targets,order_ligands]
xlsx::write.xlsx2(vis_ligand_target_network %>% t() %>% as.data.frame() %>% rownames_to_column("ligand"), "results/data_fig2.xlsx", sheetName="panel_b_ligand_target",col.names=TRUE, row.names=FALSE, append=FALSE)

#------------ Prepare figures: tumor p-EMT scores for tumor-p-EMT score heatmap  -------------

scores_pemt = readRDS("results/scores_pemt")
pemt_tumor = tibble(cell = names(scores_pemt), pemt = scores_pemt) %>% inner_join(sample_info %>% filter((tumor %in% tumors_remove == FALSE)) %>% filter(`Lymph node` == "0" & `classified  as cancer cell` == "1") %>% select(cell,tumor), by =  "cell") 
aggregated_pemt_tumor = pemt_tumor %>% group_by(tumor) %>% select(-cell) %>% summarise_all(mean)
order_tumors = aggregated_pemt_tumor %>% arrange(pemt)  %>% pull(tumor)
tumor_pemt_matrix = aggregated_pemt_tumor %>% select(pemt) %>% as.matrix() %>% magrittr::set_rownames(aggregated_pemt_tumor$tumor)

vis_tumor_pemt_matrix = tumor_pemt_matrix[order_tumors,] %>% as.matrix(ncol = 1) %>% magrittr::set_colnames("pEMT_score")
xlsx::write.xlsx2(vis_tumor_pemt_matrix %>% as.data.frame() %>% rownames_to_column("tumor_id"), "results/data_fig2.xlsx", sheetName="panel_d_tumor_score",col.names=TRUE, row.names=FALSE, append=TRUE)

#------------ Prepare figures: expression of ligands per celltype aggregated over all tumors -------------

expression_df_tme = expression[,expressed_ligands] %>% data.frame() %>% rownames_to_column("cell") %>% tbl_df() %>% inner_join(sample_info %>% filter((tumor %in% tumors_remove == FALSE)) %>% filter(`Lymph node` == "0" & `classified  as cancer cell` == "0" & `non-cancer cell type` != "0") %>% select(cell,`non-cancer cell type`), by =  "cell") 
aggregated_expression_tme = expression_df_tme %>% group_by(`non-cancer cell type`) %>% select(-cell) %>% summarise_all(mean)
aggregated_expression_df_tme = aggregated_expression_tme %>% select(-`non-cancer cell type`) %>% t() %>% magrittr::set_colnames(aggregated_expression_tme$`non-cancer cell type`) %>% data.frame() %>% rownames_to_column("ligand") %>% tbl_df() %>% select(-X.Fibroblast, -myocyte) # weird celltype annotation or too few myocytes
aggregated_expression_matrix_tme = aggregated_expression_df_tme %>% select(-ligand) %>% as.matrix() %>% magrittr::set_rownames(aggregated_expression_df_tme$ligand)

vis_ligand_celltype_expression = aggregated_expression_matrix_tme[order_ligands,]

#------------ Prepare figures: expression of top ligands in fibroblast per tumor -------------

expression_df_fibroblast = expression[,expressed_ligands] %>% data.frame() %>% rownames_to_column("cell") %>% tbl_df() %>% inner_join(sample_info %>% filter((tumor %in% tumors_remove == FALSE)) %>% filter(`Lymph node` == "0" & `classified  as cancer cell` == "0" & `non-cancer cell type` == "CAF") %>% select(cell,tumor), by =  "cell") 
aggregated_expression_fibroblast = expression_df_fibroblast %>% group_by(tumor) %>% select(-cell) %>% summarise_all(mean)
aggregated_expression_df_fibroblast = aggregated_expression_fibroblast %>% select(-tumor) %>% t() %>% magrittr::set_colnames(aggregated_expression_fibroblast$tumor) %>% data.frame() %>% rownames_to_column("ligand") %>% tbl_df() 
aggregated_expression_matrix_fibroblast = aggregated_expression_df_fibroblast %>% select(-ligand) %>% as.matrix() %>% magrittr::set_rownames(aggregated_expression_df_fibroblast$ligand)

vis_ligand_tumor_expression = aggregated_expression_matrix_fibroblast[order_ligands,order_tumors]

#------------ Prepare figures: expression of top target genes in malignant cells per tumor -------------

expression_df_target = expression[,pemt_genes] %>% data.frame() %>% rownames_to_column("cell") %>% tbl_df() %>% inner_join(sample_info %>% filter((tumor %in% tumors_remove == FALSE)) %>% filter(`Lymph node` == "0" & `classified  as cancer cell` == "1") %>% select(cell,tumor), by =  "cell") 
aggregated_expression_target = expression_df_target %>% group_by(tumor) %>% select(-cell) %>% summarise_all(mean)
aggregated_expression_df_target = aggregated_expression_target %>% select(-tumor) %>% t() %>% magrittr::set_colnames(aggregated_expression_target$tumor) %>% data.frame() %>% rownames_to_column("target") %>% tbl_df() 
aggregated_expression_matrix_target = aggregated_expression_df_target %>% select(-target) %>% as.matrix() %>% magrittr::set_rownames(aggregated_expression_df_target$target)

vis_target_tumor_expression = aggregated_expression_matrix_target[order_targets,order_tumors]
xlsx::write.xlsx2(vis_target_tumor_expression %>% t() %>% as.data.frame() %>% rownames_to_column("tumor_id"), "results/data_fig2.xlsx", sheetName="panel_c_target_expression",col.names=TRUE, row.names=FALSE, append=TRUE)

#------------ Prepare figures: ligand-receptor network heatmap for top ligands  -------------

lr_network_top_df = lr_network_top %>% mutate(weight = 1) %>% spread("from","weight",fill = 0)

lr_network_top_matrix = lr_network_top_df %>% select(-to) %>% as.matrix() %>% magrittr::set_rownames(lr_network_top_df$to)

distoi = dist(lr_network_top_matrix, method = "binary")
hclust_obj = hclust(distoi, method = "ward.D2")
order_receptors = hclust_obj$labels[hclust_obj$order]

distoi_targets = dist(lr_network_top_matrix %>% t(), method = "binary")
hclust_obj = hclust(distoi_targets, method = "ward.D2")
order_ligands_receptor = hclust_obj$labels[hclust_obj$order]

vis_ligand_receptor_network = lr_network_top_matrix[order_receptors, order_ligands_receptor]
vis_ligand_receptor_tumor_expression = aggregated_expression_matrix_fibroblast[order_ligands_receptor,order_tumors]

#------------ Prepare figures: expression of receptors for top ligands in malignant cells per tumor -------------

expression_df_receptor = expression[,expressed_receptors] %>% data.frame() %>% rownames_to_column("cell") %>% tbl_df() %>% inner_join(sample_info %>% filter((tumor %in% tumors_remove == FALSE)) %>% filter(`Lymph node` == "0" & `classified  as cancer cell` == "1") %>% select(cell,tumor), by =  "cell") 
aggregated_expression_receptor = expression_df_receptor %>% group_by(tumor) %>% select(-cell) %>% summarise_all(mean)
aggregated_expression_df_receptor = aggregated_expression_receptor %>% select(-tumor) %>% t() %>% magrittr::set_colnames(aggregated_expression_receptor$tumor) %>% data.frame() %>% rownames_to_column("receptor") %>% tbl_df() 
aggregated_expression_matrix_receptor = aggregated_expression_df_receptor %>% select(-receptor) %>% as.matrix() %>% magrittr::set_rownames(aggregated_expression_df_receptor$receptor)

vis_receptor_tumor_expression = aggregated_expression_matrix_receptor[order_receptors,order_tumors]

#------------ Prepare figures: Ligand-pearson for ligand-pearson score heatmap  -------------

ligand_pearson_matrix = ligand_importances_bg_expr %>% select(pearson) %>% as.matrix() %>% magrittr::set_rownames(ligand_importances_bg_expr$test_ligand)

vis_ligand_pearson = ligand_pearson_matrix[order_ligands, ] %>% as.matrix(ncol = 1) %>% magrittr::set_colnames("Pearson")
xlsx::write.xlsx2(vis_ligand_pearson %>% as.data.frame() %>% rownames_to_column("ligand"), "results/data_fig2.xlsx", sheetName="panel_a_ligand_activity",col.names=TRUE, row.names=FALSE, append=TRUE)

vis_ligand_receptor_pearson = ligand_pearson_matrix[order_ligands_receptor,] %>% as.matrix(ncol = 1) %>% magrittr::set_colnames("PCC")

#------------ Make combined figures  -------------

## now make heatmap figures with nichenetr package functions for paper
color = colorRampPalette(rev(brewer.pal(n = 7, name ="RdYlBu")))(100)

p_ligand_target_network = vis_ligand_target_network %>% t() %>% make_heatmap_ggplot("Prioritized CAF-ligands","Predicted target genes\n(belonging to p-EMT program in malignant cells)", color = "mediumvioletred",legend_position = "top", x_axis_position = "top", legend_title = "Ligand-target\nRegulatory potential")
p_ligand_target_network = p_ligand_target_network + scale_fill_gradient2(low = "whitesmoke",  high = "mediumvioletred", breaks = c(0,0.0035,0.007), limits = c(0,0.007)) + theme(axis.text.x = element_text(face = "italic"))
p_ligand_target_network 

p_ligand_receptor_network = vis_ligand_receptor_network %>% t() %>% make_heatmap_ggplot("Prioritized CAF-ligands","Receptors expressed by malignant cells", color = "mediumvioletred",legend_position = "none", x_axis_position = "top")
p_ligand_receptor_network

p_ligand_tumor_expression = vis_ligand_tumor_expression %>% make_heatmap_ggplot("Prioritized CAF-ligands","Tumor", color = color[1],legend_position = "top", x_axis_position = "top", legend_title = "Expression\n(averaged over\nsingle cells)") + theme(axis.text.y = element_text(face = "italic"))
p_ligand_tumor_expression

p_ligand_tumor_scaled_expression = vis_ligand_tumor_expression %>% t() %>% dynutils::scale_quantile() %>% t() %>% make_threecolor_heatmap_ggplot("Ligand","Tumor", low_color = color[1],mid_color = color[50], mid = 0.5, high_color = color[100], legend_position = "top", x_axis_position = "top" , legend_title = "Scaled expression\n(averaged over\nsingle cells)") + theme(axis.text.y = element_text(face = "italic"))
p_ligand_tumor_scaled_expression

p_ligand_receptor_tumor_expression = vis_ligand_receptor_tumor_expression %>% make_heatmap_ggplot("Prioritized CAF-ligands","Tumor", color = color[1],legend_position = "top", x_axis_position = "top", legend_title = "Expression\n(averaged over\nsingle cells)") + theme(axis.text.y = element_text(face = "italic"))
p_ligand_receptor_tumor_expression

p_ligand_receptor_tumor_scaled_expression = vis_ligand_receptor_tumor_expression %>% t() %>% dynutils::scale_quantile() %>% t() %>% make_threecolor_heatmap_ggplot("Ligand","Tumor", low_color = color[1],mid_color = color[50], mid = 0.5, high_color = color[100], legend_position = "top", x_axis_position = "top" , legend_title = "Scaled expression\n(averaged over\nsingle cells)") + theme(axis.text.y = element_text(face = "italic"))
p_ligand_receptor_tumor_scaled_expression

p_ligand_celltype_expression = vis_ligand_celltype_expression %>% make_heatmap_ggplot("Prioritized CAF-ligands","Cell type", color = color[1],legend_position = "top", x_axis_position = "top", legend_title = "Expression\n(averaged over\nsingle cells)") + theme(axis.text.y = element_text(face = "italic"))
p_ligand_celltype_expression

p_target_tumor_scaled_expression = vis_target_tumor_expression %>% t() %>% dynutils::scale_quantile() %>% make_threecolor_heatmap_ggplot("Tumor","Target", low_color = color[1],mid_color = color[50], mid = 0.5, high_color = color[100], legend_position = "top", x_axis_position = "top" , legend_title = "Scaled expression\n(averaged over\nsingle cells)") + theme(axis.text.x = element_text(face = "italic"))
p_target_tumor_scaled_expression

p_target_tumor_expression = vis_target_tumor_expression %>% t() %>% make_heatmap_ggplot("Tumor","Target gene", color = color[100],legend_position = "top", x_axis_position = "top", legend_title = "Expression\n(averaged over\nsingle cells)") + theme(axis.text.x = element_text(face = "italic"))
p_target_tumor_expression

p_receptor_tumor_scaled_expression = vis_receptor_tumor_expression %>% t() %>% dynutils::scale_quantile() %>% make_threecolor_heatmap_ggplot("Tumor","Receptors expressed by malignant cells", low_color = color[1],mid_color = color[50], mid = 0.5, high_color = color[100], legend_position = "top", x_axis_position = "top" , legend_title = "Scaled expression\n(averaged over\nsingle cells)") + theme(axis.text.x = element_text(face = "italic"))
p_receptor_tumor_scaled_expression

p_receptor_tumor_expression = vis_receptor_tumor_expression %>% t() %>% make_heatmap_ggplot("Tumor","Receptors expressed by malignant cells", color = color[100],legend_position = "top", x_axis_position = "top", legend_title = "Expression\n(averaged over\nsingle cells)") + theme(axis.text.x = element_text(face = "italic"))
p_receptor_tumor_expression

p_ligand_pearson = vis_ligand_pearson %>% make_heatmap_ggplot("Prioritized CAF-ligands","Ligand\nactivity", color = "darkorange",legend_position = "top", x_axis_position = "top", legend_title = "Pearson correlation coefficient\ntarget gene prediction ability", x_axis = TRUE)
p_ligand_pearson

p_ligand_receptor_pearson = vis_ligand_receptor_pearson %>% make_heatmap_ggplot("Prioritized CAF-ligands","Ligand\nactivity", color = "darkorange",legend_position = "top", x_axis_position = "top", legend_title = "Pearson correlation coefficient\ntarget gene prediction ability", x_axis = TRUE)
p_ligand_receptor_pearson

color_pemt_score = colorRampPalette(rev(brewer.pal(n = 7, name ="Spectral")))(100)
p_tumor_pemt = vis_tumor_pemt_matrix %>% make_threecolor_heatmap_ggplot("Tumor","", low_color = color_pemt_score[1],mid_color = "whitesmoke", mid = 0, high_color = color_pemt_score[100], legend_position = "top", x_axis_position = "top" , legend_title = "p-EMT\nscore\n(averaged over\nsingle cells)")
p_tumor_pemt

# ------------ ligand-receptor summary -------------- 

figures_without_legend = cowplot::plot_grid(
  p_ligand_receptor_tumor_expression + theme(legend.position = "none", axis.ticks = element_blank()), 
  p_ligand_receptor_network + theme(legend.position = "none", axis.ticks = element_blank()) + ylab(""), 
  p_ligand_receptor_pearson + theme(legend.position = "none", axis.ticks = element_blank()) + ylab("")  + theme(axis.title.x = element_text()),
  NULL, 
  p_receptor_tumor_expression + theme(legend.position = "none", axis.ticks = element_blank()) + xlab(""), 
  p_tumor_pemt + theme(legend.position = "none", axis.ticks = element_blank()) + ylab("") + theme(axis.title.x = element_text()),
  align = "hv",
  nrow = 2,
  rel_widths = c(ncol(vis_ligand_receptor_tumor_expression) -2, ncol(vis_ligand_receptor_network) +5, ncol(vis_ligand_receptor_pearson) + 3),
  rel_heights = c(nrow(vis_ligand_receptor_tumor_expression) -2, ncol(vis_receptor_tumor_expression)) + 3)
figures_without_legend
legends = cowplot::plot_grid(
  ggpubr::as_ggplot(ggpubr::get_legend(p_ligand_receptor_tumor_expression)),
  ggpubr::as_ggplot(ggpubr::get_legend(p_ligand_receptor_pearson)),
  ggpubr::as_ggplot(ggpubr::get_legend(p_receptor_tumor_expression)),
  ggpubr::as_ggplot(ggpubr::get_legend(p_tumor_pemt)),
  nrow = 1,
  align = "h")
# legends_test = cowplot::plot_grid(
#   ggpubr::as_ggplot(ggpubr::get_legend(p_ligand_receptor_tumor_scaled_expression)),
#   ggpubr::as_ggplot(ggpubr::get_legend(p_ligand_receptor_pearson)),
#   ggpubr::as_ggplot(ggpubr::get_legend(p_tumor_pemt)),
#   nrow = 3,
#   align = "v")
# 
# cowplot::plot_grid(
#   p_ligand_receptor_tumor_scaled_expression + theme(legend.position = "none", axis.ticks = element_blank()), 
#   p_ligand_receptor_network + theme(legend.position = "none", axis.ticks = element_blank()) + ylab(""), 
#   p_ligand_receptor_pearson + theme(legend.position = "none", axis.ticks = element_blank()) + ylab("") + xlab("Target\nprediction") + theme(axis.title.x = element_text()) + scale_x_discrete(position = "top"),
#   legends_test, 
#   p_receptor_tumor_scaled_expression + theme(legend.position = "none", axis.ticks = element_blank()) + xlab(""), 
#   p_tumor_pemt + theme(legend.position = "none", axis.ticks = element_blank()) + xlab("p-EMT score") + ylab("") + theme(axis.title.x = element_text()) + scale_x_discrete(position = "top"),
#   align = "hv",
#   nrow = 2,
#   rel_widths = c(ncol(vis_ligand_receptor_tumor_expression) -2, ncol(vis_ligand_receptor_network), ncol(vis_ligand_receptor_pearson)) + 1.5,
#   rel_heights = c(nrow(vis_ligand_receptor_tumor_expression) -2, ncol(vis_receptor_tumor_expression)) + 3)

# cowplot::plot_grid(figures_without_legend,legends, rel_widths =  c(10,1), nrow = 1, align = "hv")
cowplot::plot_grid(figures_without_legend,legends, rel_heights = c(20,3), nrow = 2, align = "hv")
# cowplot::plot_grid(figures_without_legend,legends, rel_heights = c(15,1), nrow = 2, align = "hv") %>% cowplot::save_plot(filename = "results/summary_ligand_receptor.png",., base_height = 7, base_aspect_ratio = 1, base_width = 12)

dev.off()
png("results/summary_ligand_receptor_k2.png",width = 1100, height = 1000)
cowplot::plot_grid(figures_without_legend,legends, rel_heights = c(15,1), nrow = 2, align = "hv")
dev.off()

dev.off()
svg("results/summary_ligand_receptor_k2.svg",width = 12, height = 11)
cowplot::plot_grid(figures_without_legend,legends, rel_heights = c(15,1), nrow = 2, align = "hv")
dev.off()

# ------------ ligand-target summary -------------- 
figures_without_legend = cowplot::plot_grid(
  p_ligand_pearson + theme(legend.position = "none", axis.ticks = element_blank()) + theme(axis.title.x = element_text()),
  p_ligand_target_network + theme(legend.position = "none", axis.ticks = element_blank()) + ylab(""), 
  NULL,
  NULL,
  p_target_tumor_scaled_expression + theme(legend.position = "none", axis.ticks = element_blank()) + xlab(""), 
  p_tumor_pemt + theme(legend.position = "none", axis.ticks = element_blank()) + ylab("") + theme(axis.title.x = element_text()),
  align = "hv",
  nrow = 2,
  rel_widths = c(ncol(vis_ligand_pearson)+3, nrow(vis_ligand_target_network), ncol(vis_ligand_pearson) + 3),
  rel_heights = c(ncol(vis_ligand_target_network), ncol(vis_target_tumor_expression) + 3)) 

legends = cowplot::plot_grid(
  ggpubr::as_ggplot(ggpubr::get_legend(p_ligand_pearson)),
  ggpubr::as_ggplot(ggpubr::get_legend(p_ligand_target_network)),
  ggpubr::as_ggplot(ggpubr::get_legend(p_target_tumor_scaled_expression)),
  ggpubr::as_ggplot(ggpubr::get_legend(p_tumor_pemt)),
  nrow = 1,
  align = "h")

# figures_without_legend = cowplot::plot_grid(
#   p_ligand_tumor_scaled_expression + theme(legend.position = "none", axis.ticks = element_blank()), 
#   p_ligand_target_network + theme(legend.position = "none", axis.ticks = element_blank()) + ylab(""), 
#   p_ligand_pearson + theme(legend.position = "none", axis.ticks = element_blank()) + ylab("") + theme(axis.title.x = element_text()),
#   NULL, 
#   p_target_tumor_scaled_expression + theme(legend.position = "none", axis.ticks = element_blank()) + xlab(""), 
#   p_tumor_pemt + theme(legend.position = "none", axis.ticks = element_blank()) + ylab("") + theme(axis.title.x = element_text()),
#   align = "hv",
#   nrow = 2,
#   rel_widths = c(ncol(vis_ligand_tumor_expression) -2, ncol(vis_ligand_target_network), ncol(vis_ligand_pearson)) + 2.5,
#   rel_heights = c(nrow(vis_ligand_tumor_expression) -2, ncol(vis_target_tumor_expression)) + 3)
# legends = cowplot::plot_grid(
#   ggpubr::as_ggplot(ggpubr::get_legend(p_ligand_tumor_scaled_expression)),
#   ggpubr::as_ggplot(ggpubr::get_legend(p_ligand_target_network)),
#   ggpubr::as_ggplot(ggpubr::get_legend(p_ligand_pearson)),
#   ggpubr::as_ggplot(ggpubr::get_legend(p_tumor_pemt)),
#   nrow = 1,
#   align = "h")

cowplot::plot_grid(figures_without_legend,legends, rel_heights = c(10,1), nrow = 2, align = "hv")

dev.off()
png("results/summary_ligand_target_k2.png",width = 1100, height = 600)
cowplot::plot_grid(figures_without_legend,legends, rel_heights = c(15,1.5), nrow = 2, align = "hv")
dev.off()

dev.off()
svg("results/summary_ligand_target_k2.svg",width = 13, height = 8)
cowplot::plot_grid(figures_without_legend,legends, rel_heights = c(15,1.5), nrow = 2, align = "hv")
dev.off()


# ------------ ligand-target summary: cellular expression -------------- 

figures_without_legend = cowplot::plot_grid(
  p_ligand_celltype_expression + theme(legend.position = "none", axis.ticks = element_blank()), 
  p_ligand_target_network + theme(legend.position = "none", axis.ticks = element_blank()) + ylab(""), 
  p_ligand_pearson + theme(legend.position = "none", axis.ticks = element_blank()) + ylab("") + theme(axis.title.x = element_text()),
  NULL, 
  p_target_tumor_scaled_expression + theme(legend.position = "none", axis.ticks = element_blank()) + xlab(""), 
  p_tumor_pemt + theme(legend.position = "none", axis.ticks = element_blank()) + ylab("") + theme(axis.title.x = element_text()),
  align = "hv",
  nrow = 2,
  rel_widths = c(ncol(vis_ligand_tumor_expression) -2, ncol(vis_ligand_target_network), ncol(vis_ligand_pearson)) + 2.5,
  rel_heights = c(nrow(vis_ligand_tumor_expression) -2, ncol(vis_target_tumor_expression)) + 3)
legends = cowplot::plot_grid(
  ggpubr::as_ggplot(ggpubr::get_legend(p_ligand_celltype_expression)),
  ggpubr::as_ggplot(ggpubr::get_legend(p_ligand_target_network)),
  ggpubr::as_ggplot(ggpubr::get_legend(p_ligand_pearson)),
  ggpubr::as_ggplot(ggpubr::get_legend(p_target_tumor_scaled_expression)),
  ggpubr::as_ggplot(ggpubr::get_legend(p_tumor_pemt)),
  nrow = 1,
  align = "h")

cowplot::plot_grid(figures_without_legend,legends, rel_heights = c(10,1), nrow = 2, align = "hv")

dev.off()
png("results/summary_ligand_target_celltype_k2.png",width = 1100, height = 600)
cowplot::plot_grid(figures_without_legend,legends, rel_heights = c(15,1.5), nrow = 2, align = "hv")
dev.off()

dev.off()
svg("results/summary_ligand_target_celltype_k2.svg",width = 14, height = 9)
cowplot::plot_grid(figures_without_legend,legends, rel_heights = c(15,1.5), nrow = 2, align = "hv")
dev.off()

