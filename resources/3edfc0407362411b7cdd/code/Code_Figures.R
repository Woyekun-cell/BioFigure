# Code for Figures of ""
# by Can Cui at Reliability and Risk Engineering Group, ETH Zurich

# Load packages and data
library(dplyr)
library(ggplot2)
library(circlize)
library(forcats)
library(scales)

setwd('C://your_folder/')
load('Data_Figures.RData')

# Figure 1 c -----

production_relative_2030_2022%>% 
  right_join(world_map,by='region12') %>%
  ggplot() +
  geom_polygon(aes(x = long, y = lat, group = group, fill = legend), alpha=0.9,
               color = 'white', linewidth = 0.1) +
  ylim(c(-60, 90)) +
  scale_fill_manual(values = c('#ffffcc','#c7e9b4','#7fcdbb','#41b6c4','#2c7fb8','#253494'))+
  theme_minimal() +
  theme(axis.text = element_blank(),
        axis.title = element_blank(),
        panel.grid = element_blank())
ggsave('Fig1_c_map_2030_production_relative_to_2022.pdf',height = 3,width = 7)


# Figure 2 -----

# Figure 2a
mycolors <- c(
  '#56a0d3','#66336e','#56687a','#e7a33e',
  '#fce2ba','#f0b7bd','#f5987e','#009bbb',
  '#969696','#862633','#54826c','#cd595a','#006fbf')
pdf('Fig2_a_trade_2022.pdf',height = 3,width = 10)
par(mfrow = c(1,5),  mar = rep(0.1, 4))
for (data in list_of_trade22) {
  datai <- data[,c(1,2,4)]%>%unique()
  circos.clear()
  unique_sectors <- unique(c(datai$From, datai$To))
  color_mapping <- setNames(mycolors, all_regions1)
  circos.par(start.degree = 90, gap.degree = 2, #4
             points.overflow.warning = FALSE)
  unique_sectors <- unique(c(datai$From, datai$To))
  chordDiagram(datai ,
               grid.col = color_mapping[datai$From],
               grid.border = NA,
               transparency = 0.25,
               directional = 1,
               direction.type = c("arrows", "diffHeight"),
               diffHeight = -0.04,
               annotationTrack = "grid",
               annotationTrackHeight = c(0.05, 0.1),
               link.border = 'white',
               link.lwd = 0.05,
               link.arr.type = "big.arrow",
               link.sort = TRUE,
               link.largest.ontop = TRUE
  )
  circos.trackPlotRegion(track.index = 1, panel.fun = function(x, y) {
    xlim = get.cell.meta.data("xlim")
    ylim = get.cell.meta.data("ylim")
    sector.name = get.cell.meta.data("sector.index")
    circos.text(mean(xlim), ylim[1] -0.5, sector.name, 
                facing = "clockwise", niceFacing = TRUE, adj = c(-0.5, 0.5))
  })
  title(main = paste(unique(data$Product)), cex.main =1)
}
dev.off()

# Figure 2b
pdf('Fig2_b_tradeflows_scenarios_2030.pdf',height = 10,width = 10)
par(mfrow = c(5,5), mar = rep(0.1, 4))

color_mapping <- setNames(mycolors, all_regions1)

for (sce in c('Baseline','MaximizeEuropeanJobs','MEJ+Eu>40%self-sufficiency',
              'EuropeanTradeBarrier','EuropeanModuleSubsidies')) {
  list_of_df1 <- flows2030 %>% 
    filter(scenario_name==sce)%>% 
    split(., list( .$scenario_name,.$Product)) 
  for (data in list_of_df1) {
    datai <- data[,c('From','To','Value')]%>%
      unique() %>% 
      mutate(From=factor(From,levels=all_regions1),
             To=factor(To,levels=all_regions1)) 
    circos.clear()
    circos.par(start.degree = 90, gap.degree = 2, 
               points.overflow.warning = FALSE)
    unique_sectors <- unique(c(datai$From, datai$To))
    chordDiagram(datai ,
                 grid.col = color_mapping[datai$From],
                 grid.border = NA,
                 transparency = 0.25,
                 directional = 1,
                 direction.type = c("arrows", "diffHeight"),
                 diffHeight = -0.04,
                 annotationTrack = "grid",
                 annotationTrackHeight = c(0.05, 0.1),
                 link.border = 'white',
                 link.lwd = 0.05,
                 link.arr.type = "big.arrow",
                 link.sort = TRUE,
                 link.largest.ontop = TRUE
    )
    circos.trackPlotRegion(track.index = 1, panel.fun = function(x, y) {
      xlim = get.cell.meta.data("xlim")
      ylim = get.cell.meta.data("ylim")
      sector.name = get.cell.meta.data("sector.index")
      circos.text(mean(xlim), ylim[1] + 0.1, sector.name, 
                  facing = "clockwise", niceFacing = TRUE, adj = c(-0.5, 0.5))
    })
    title(main = paste(unique(data$scenario_name),
                       unique(data$Product)), cex.main = 0.8)
  }
  print(sce)
}
dev.off()

# Figure 3 -----
# Figure 3a-d
new_flabels <- list('costs' = "Global costs (Trillion USD)", 
                    'co2' = "CO2 emissions (Gt)",
                    'import' = 'Global imports (TW)', 
                    'job' = 'Global jobs (Million)',
                    'local' = 'Global self-sufficiency')
flabeller <- function(variable,value){
  return(new_flabels[value])
}
global_indicators%>% 
  ggplot(aes(y=Scenario,  
             color=Scenario))+
  geom_errorbarh(aes(xmin = Minr, xmax = Maxr), height = 0.2,linewidth=0.25,
                 alpha=1,position = position_dodge(width = 1)) +  
  geom_point(aes(x=Medianr, 
                 color=Scenario),shape=21,fill='white',
             size=2,alpha=1,position = position_dodge(width = 1))+
  facet_wrap(~factor, scales = 'free_x',labeller = flabeller,ncol = 5,strip.position = "top")+
  theme_minimal()+
  xlab('')+ylab('')+
  scale_color_manual(values = c('#66336e','#e7a33e','#56a0d3','#75af42'))+
  theme(panel.spacing = unit(1, "lines"),
        panel.border = element_rect(colour = "black",fill=NA, linewidth = 0.25),
        panel.grid.major.y = element_blank(),
        panel.grid.minor.x = element_blank(),axis.text.y = element_blank()
  )
ggsave('Fig3_a_d_comparison.pdf',height =2.5,width = 10.45)

# Figure 3e-g
eujobs_selfsuff %>% 
  ggplot(aes(x = MedianJob, y = MedianCost,color = scenario)) +
  geom_point(aes(alpha=selfsuff), size = 2.5) + 
  geom_smooth(method = "lm", se = FALSE,color='black',linewidth=0.5) + 
  geom_text(data = unique(eujobs_selfsuff[, c("scenario", "slope")]),
            aes(x = 870, y = 460, label = sprintf("Slope: %.2f", slope),color=scenario),
            hjust = 1, vjust = 1, size=3, inherit.aes = FALSE)+
  scale_color_manual(values = c('#56a0d3','#009bbb','#56687a')) + # ,guide='none'
  scale_alpha_continuous(breaks=c(0,0.3,0.6,0.9),name='Self-sufficiency')+
  labs(#title = "Costs vs. Jobs in Europe by Scenario",
    y = "Costs (Billion USD)",
    x = "Jobs in Europe (Thousand)") +
  facet_grid(~scenario)+
  theme_minimal() +
  theme(panel.spacing = unit(1, "lines"),
        panel.border = element_rect(fill=NA,linewidth = 0.2),
        panel.grid.minor.y = element_blank(),
        panel.grid.minor.x = element_blank())
ggsave('Fig3_e_g_costjobs.pdf',width = 8,height = 2.5)


# Figure 4 -----

# Figure 4a

cost_cap_expansion %>% 
  ggplot(aes(x=diff3022/1e9,y=fct_rev(scenario),
    fill=factor(product,levels = c('module','cell','wafer','ingots','polysilicon'))))+
  geom_bar(stat = "identity", position = "stack") +
  facet_wrap(region~variable, scales = "free_x", ncol = 2) +#
  scale_fill_manual(name='Product',values = c("#862633", "#cd595a", "#f5987e", "#e7a33e", "#66336e")) +
  scale_x_continuous(expand = c(0.1,0),labels = function(x) abs(x))+
  theme_minimal() +
  theme(panel.grid.minor = element_blank(),legend.position = 'top')+
  labs(x = "", y = "Scenario") 
ggsave('Fig4_a_capacity_expansion_cost_diff3022.pdf',height =10,width = 6)


# Figure 4b
cumu_cost_self_suff %>% 
  ggplot()+
  geom_bar(aes(x=as.numeric(substr(scenario,2,3))/100,
               y =  Meanvalue/1e9, fill = variable),
           position='stack',stat = 'identity') +
  xlab('Europe self-sufficiency requirement by 2030')+
  ylab('Cumulative costs (Billion USD)')+
  theme_minimal() +
  scale_x_continuous(labels = percent,limits = c(-0.05,0.95),breaks = c(0,0.3,0.6,0.9))+
  scale_y_continuous()+
  scale_fill_manual(values = c("#56687a", "#56a0d3", "#75af42", "#006fbf", "#00a98f"), 
                    labels=c('Capacity','Production','Exports','Imports','Stocks'), name='Cost types')+
  facet_grid(product~sgroup,scales = 'free_x')+
  theme(panel.grid.minor = element_blank(),legend.position = 'top'
  )
ggsave(paste0('Fig4_b_cost_vs_self_sufficiency.pdf'),width = 6,height =10)

