library(extrafont)
library(dplyr)
library(ggplot2)
library(patchwork)
library(ggpubr)
library(ComplexHeatmap)
library(circlize)
library(RColorBrewer)
library(ggsci)
library(extrafont)

color <- readRDS("/raid1/shiq/resource/color/color_list.rds")

#########################################
# (0) overlap
######################################
B03 <- read.csv("./04_spleen_scenic/rss/B03_rss_order.csv")
B05 <- read.csv("./04_spleen_scenic/rss/B05_rss_order.csv")
CD4T03 <- read.csv("./04_spleen_scenic/rss/CD4T03_rss_order.csv")
I06 <- read.csv("./04_spleen_scenic/rss/I06_rss_order.csv")

n <- 50
B03 <- B03[1:n, "X"]
B05 <- B05[1:n, "X"]
CD4T03 <- CD4T03[1:n, "X"]
I06 <- I06[1:n, "X"]

### Venn
pdf("spleen_scenic_venn.pdf", width = 1, height = 1, family = "Arial")
venn::venn(
    x = list(
        B03 = B03,
        B05 = B05,
        CD4T03 = CD4T03,
        I06 = I06
    ),
    ilabels = "counts", box = FALSE, # ellipse = TRUE,
    ilcs = 0.4, sncs = 0.4,
    zcolor = c(
        "B03" = pal_d3("category20")(11)[11],
        "B05" = color$majorCluster["B"] %>% unname(),
        "CD4T03" = color$majorCluster["CD4T"] %>% unname(),
        "I06" = color$majorCluster["ILC"] %>% unname()
    ), col = NA
    # col = c(
    #     "B03" = pal_d3("category20")(11)[11],
    #     "B05" = color$majorCluster["B"] %>% unname(),
    #     "CD4T03" = color$majorCluster["CD4T"] %>% unname(),
    #     "I06" = color$majorCluster["ILC"] %>% unname()
    # )
)
dev.off()

tf <- Reduce(intersect, list(B03, B05, CD4T03, I06))
tf



########## Heatmap
# (1) prepare
# B
meta_B <- read.csv("./04_spleen_scenic/result/meta_B.csv", row.names = 1)
meta_B <- meta_B[meta_B$subCluster %in% c("B03_Bn_NR4A2", "B05_Bm_NR4A2"), ]
B <- read.csv("./04_spleen_scenic/result/B_auc.csv", row.names = 1, check = FALSE)
B <- B[rownames(meta_B), tf]

# CD4T
meta_CD4T <- read.csv("./04_spleen_scenic/result/meta_CD4T.csv", row.names = 1)
meta_CD4T <- meta_CD4T[meta_CD4T$subCluster %in% c("CD4T03_Tn_NR4A1"), ]
CD4T <- read.csv("./04_spleen_scenic/result/CD4T_auc.csv", row.names = 1, check = FALSE)
CD4T <- CD4T[rownames(meta_CD4T), tf]

# ILC
meta_ILC <- read.csv("./04_spleen_scenic/result/meta_ILC.csv", row.names = 1)
meta_ILC <- meta_ILC[meta_ILC$subCluster %in% c("I06_CD16loNK_NR4A2"), ]
ILC <- read.csv("./04_spleen_scenic/result/ILC_auc.csv", row.names = 1, check = FALSE)
ILC <- ILC[rownames(meta_ILC), tf]

# merge
mat <- rbind(B, CD4T, ILC)
meta <- rbind(meta_B, meta_CD4T, meta_ILC)

# delete samples without age_groups (Unknown)
meta_sp <- readRDS("./meta_sample_phenotype.rds")
meta$age_gp <- meta_sp$age_gp[match(meta$sampleID, meta_sp$sampleID)]
meta <- meta[meta$age_gp != "Unknown", ]
table(meta$age_gp, meta$age)
mat <- mat[rownames(meta), ]

# mean by subset and age_groups
if (all(rownames(mat) == rownames(meta))) {
    mat$subCluster <- meta$subCluster
    mat$age_gp <- meta$age_gp
}

tmp <- aggregate(. ~ subCluster + age_gp, data = mat, FUN = mean)
tmp2 <- reshape2::melt(
    data = tmp,
    id.vars = c("subCluster", "age_gp"),
    variable.name = "regulon"
)
tmp3 <- reshape2::dcast(
    data = tmp2,
    formula = regulon + subCluster ~ age_gp
)

rownames(tmp3) <- paste(tmp3$regulon, tmp3$subCluster, sep = "-")
tmp3$regulon <- as.character(tmp3$regulon)
str(tmp3)

mat <- tmp3[, -c(1:2)]

#####


#########################################
# (2) plot
######################################
Heatmap(mat, cluster_columns = F, cluster_rows = F)
Heatmap(t(scale(t(mat))), cluster_columns = F)

pdf("Figure4c.pdf", width = 2.5, height = 2.5, family = "Arial")
# 0) set
par(mar = c(0, 0, 0, 0), family = "Arial")
circos.clear()
circos.par(
    start.degree = 62,
    gap.after = c(rep(2, 16), 30)
)
# 1) subset ann
col_direction <- c(
    "B03_Bn_NR4A2" = pal_d3("category20")(11)[11],
    "B05_Bm_NR4A2" = color$majorCluster["B"] %>% unname(),
    "CD4T03_Tn_NR4A1" = color$majorCluster["CD4T"] %>% unname(),
    "I06_CD16loNK_NR4A2" = color$majorCluster["ILC"] %>% unname()
)
circos.heatmap(
    mat = tmp3$subCluster,
    split = factor(tmp3$regulon),
    col = col_direction, track.height = 0.05
)
# 2) regulon ann
circos.track(
    track.index = get.current.track.index(),
    panel.fun = function(x, y) {
        circos.text(
            x = CELL_META$xcenter,
            y = CELL_META$cell.ylim[2] + convert_y(1, "mm"),
            labels = CELL_META$sector.index,
            facing = "bending.inside", cex = 0.4,
            adj = c(0.5, 0), niceFacing = TRUE
        )
    }, bg.border = NA
)
# 3) heatmap
circos.heatmap(
    mat = tmp3[, -c(1:2)], split = factor(tmp3$regulon),
    track.height = 0.5, cluster = FALSE,
    col = colorRamp2(seq(0, 0.1, length.out = 4), brewer.pal(n = 7, name = "RdBu")[4:7])
)
# 4) age_groups
circos.track(track.index = get.current.track.index(), panel.fun = function(x, y) {
    if (CELL_META$sector.numeric.index == 17) { # the last sector
        cn <- colnames(mat)
        n <- length(cn)
        circos.text(rep(CELL_META$cell.xlim[2], n) + convert_x(1, "mm"),
            n - 1:n + 0.5, cn,
            cex = 0.4, adj = c(0, 0.5), facing = "inside"
        )
    }
}, bg.border = NA)
dev.off()

#####
