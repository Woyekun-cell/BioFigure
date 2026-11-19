#######################################################################################################
###########        Analysis of first 100,000 SARS-CoV-2 Sequences from Africa     ######################
###########     Author: Houriiyah Tegally, CERI/KRISP, Stellenbosch Uni & UKZN   ######################
#######################################################################################################

#Please also note that the genomic metadata shared in this training
#belong to the individual data generators in each African country and
#should only be used while complying to the GISAID terms and conditions

library(ggplot2)
library("readxl")
library(tidyverse)
library(dplyr)
library(ggpubr)
library(cowplot)
library(ggthemes)
library(viridis)
library(ggrepel)
library('gridExtra')
library('data.table')
library('scales')
library('lubridate')

library('gganimate')


library(ggtree)
library(tidytree)
library(treeio)

library(sp)
library(rworldmap)


############# Import Export Results

#world<-map_data(world)

world_data<-getMap(resolution='low')@data

country2continent = function(x)
{  
  country_data = subset(world_data, NAME==x)
  
  return (as.character(country_data[['REGION']]))   # returns the continent (7 continent model)
}


country2continent_region = function(x)
{  
  country_data = subset(world_data, NAME==x)
  
  return (as.character(country_data[['IMAGE24']]))  
}


country2lat = function(x)
{  
  country_data = subset(world_data, NAME==x)
  
  return (as.numeric(country_data[['LAT']]))  
}


country2long = function(x)
{  
  country_data = subset(world_data, NAME==x)
  
  return (as.numeric(country_data[['LON']]))  
}

###Date to reach 100k sequences in GISAID: 30 March 2022


#Genomic data
global_metadata<-read.csv('metadata_2022-03-30_23-13.tsv',sep = "\t")
### have to select only humans and only original passage
africa_metadata<-subset(global_metadata, region=='Africa')


## Alpha



replicate1<-read.table(file='ImportExport/Alpha_Africa_focused_0.0008/1annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate1$replicate <- "1"
replicate2<-read.table(file='ImportExport/Alpha_Africa_focused_0.0008/2annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate2$replicate <- "2"
replicate3<-read.table(file='ImportExport/Alpha_Africa_focused_0.0008/3annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate3$replicate <- "3"
replicate4<-read.table(file='ImportExport/Alpha_Africa_focused_0.0008/4annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate4$replicate <- "4"
replicate5<-read.table(file='ImportExport/Alpha_Africa_focused_0.0008/5annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate5$replicate <- "5"
replicate6<-read.table(file='ImportExport/Alpha_Africa_focused_0.0008/6annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate6$replicate <- "6"
replicate7<-read.table(file='ImportExport/Alpha_Africa_focused_0.0008/7annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate7$replicate <- "7"
replicate8<-read.table(file='ImportExport/Alpha_Africa_focused_0.0008/8annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate8$replicate <- "8"
replicate9<-read.table(file='ImportExport/Alpha_Africa_focused_0.0008/9annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate9$replicate <- "9"
replicate10<-read.table(file='ImportExport/Alpha_Africa_focused_0.0008/10annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate10$replicate <- "10"

#alpha_all_replicates<-rbind(replicate1,replicate2,replicate3)

alpha_all_replicates<-rbind(replicate1,replicate2,replicate3,replicate4,
                            replicate5,replicate6,replicate7,replicate8,
                            replicate9,replicate10)
alpha_all_replicates[alpha_all_replicates == "USA"] <- "United States"
alpha_all_replicates[alpha_all_replicates == "Republic of the Congo"] <- "Congo (Brazzaville)"
alpha_all_replicates[alpha_all_replicates == "Democratic Republic of the Congo"] <- "Congo (Kinshasa)"

alpha_all_replicates[alpha_all_replicates == "Coted Ivoire"] <- "Ivory Coast"

alpha_all_replicates<-subset(alpha_all_replicates,Origin!='Reunion')
alpha_all_replicates<-subset(alpha_all_replicates,Origin!='Mayotte')

alpha_all_replicates$date<-date_decimal(alpha_all_replicates$EventTime)

alpha_all_replicates$Origin_Continent<-lapply(alpha_all_replicates$Origin,country2continent)
alpha_all_replicates$Destination_Continent<-lapply(alpha_all_replicates$Destination,country2continent)

alpha_all_replicates$Origin_Continent_Region<-lapply(alpha_all_replicates$Origin,country2continent_region)
alpha_all_replicates$Destination_Continent_Region<-lapply(alpha_all_replicates$Destination,country2continent_region)

alpha_all_replicates$Variant <- "Alpha"

alpha_all_replicates$days<-as.Date(cut(alpha_all_replicates$date,breaks = "day",start.on.monday = FALSE))
alpha_all_replicates$date<-as.Date(cut(alpha_all_replicates$date,breaks = "week",start.on.monday = FALSE))
alpha_all_replicates$date2<-as.Date(cut(alpha_all_replicates$date,breaks = "2 week",start.on.monday = FALSE))
alpha_all_replicates$date4<-as.Date(cut(alpha_all_replicates$date,breaks = "1 month",start.on.monday = FALSE))


alpha_all_replicates$destination_lat<- lapply(alpha_all_replicates$Destination,country2lat)
alpha_all_replicates$destination_long<- lapply(alpha_all_replicates$Destination,country2long)

alpha_all_replicates$origin_lat<- lapply(alpha_all_replicates$Origin,country2lat)
alpha_all_replicates$origin_long<- lapply(alpha_all_replicates$Origin,country2long)

alpha_all_replicates_africa_0008<-alpha_all_replicates

replicate1<-read.table(file='ImportExport/Alpha_0.0008/africa_seed1234_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate1$replicate <- "1"
replicate2<-read.table(file='ImportExport/Alpha_0.0008/africa_seed1898_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate2$replicate <- "2"
replicate3<-read.table(file='ImportExport/Alpha_0.0008/africa_seed2007_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate3$replicate <- "3"
replicate4<-read.table(file='ImportExport/Alpha_0.0008/africa_seed2498_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate4$replicate <- "4"
replicate5<-read.table(file='ImportExport/Alpha_0.0008/africa_seed3107_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate5$replicate <- "5"
replicate6<-read.table(file='ImportExport/Alpha_0.0008/africa_seed4321_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate6$replicate <- "6"
replicate7<-read.table(file='ImportExport/Alpha_0.0008/africa_seed4891_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate7$replicate <- "7"
replicate8<-read.table(file='ImportExport/Alpha_0.0008/africa_seed5327_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate8$replicate <- "8"
replicate9<-read.table(file='ImportExport/Alpha_0.0008/africa_seed6404_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate9$replicate <- "9"
replicate10<-read.table(file='ImportExport/Alpha_0.0008/africa_seed7102_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate10$replicate <- "10"

#alpha_all_replicates<-rbind(replicate1,replicate2,replicate3)

alpha_all_replicates<-rbind(replicate1,replicate2,replicate3,replicate4,
                            replicate5,replicate6,replicate7,replicate8,
                            replicate9,replicate10)
alpha_all_replicates[alpha_all_replicates == "USA"] <- "United States"
alpha_all_replicates[alpha_all_replicates == "Republic of the Congo"] <- "Congo (Brazzaville)"
alpha_all_replicates[alpha_all_replicates == "Democratic Republic of the Congo"] <- "Congo (Kinshasa)"

alpha_all_replicates[alpha_all_replicates == "Coted Ivoire"] <- "Ivory Coast"

alpha_all_replicates<-subset(alpha_all_replicates,Origin!='Reunion')
alpha_all_replicates<-subset(alpha_all_replicates,Origin!='Mayotte')

alpha_all_replicates$date<-date_decimal(alpha_all_replicates$EventTime)

alpha_all_replicates$Origin_Continent<-lapply(alpha_all_replicates$Origin,country2continent)
alpha_all_replicates$Destination_Continent<-lapply(alpha_all_replicates$Destination,country2continent)

alpha_all_replicates$Origin_Continent_Region<-lapply(alpha_all_replicates$Origin,country2continent_region)
alpha_all_replicates$Destination_Continent_Region<-lapply(alpha_all_replicates$Destination,country2continent_region)

alpha_all_replicates$Variant <- "Alpha"

alpha_all_replicates$days<-as.Date(cut(alpha_all_replicates$date,breaks = "day",start.on.monday = FALSE))
alpha_all_replicates$date<-as.Date(cut(alpha_all_replicates$date,breaks = "week",start.on.monday = FALSE))
alpha_all_replicates$date2<-as.Date(cut(alpha_all_replicates$date,breaks = "2 week",start.on.monday = FALSE))
alpha_all_replicates$date4<-as.Date(cut(alpha_all_replicates$date,breaks = "1 month",start.on.monday = FALSE))


alpha_all_replicates$destination_lat<- lapply(alpha_all_replicates$Destination,country2lat)
alpha_all_replicates$destination_long<- lapply(alpha_all_replicates$Destination,country2long)

alpha_all_replicates$origin_lat<- lapply(alpha_all_replicates$Origin,country2lat)
alpha_all_replicates$origin_long<- lapply(alpha_all_replicates$Origin,country2long)


alpha_all_replicates_global_0008<-alpha_all_replicates

alpha_all_replicates<-alpha_all_replicates_global_0008

unique(subset(alpha_all_replicates,Destination_Continent=='Africa')$Origin_Continent_Region)
unique(subset(alpha_all_replicates,Destination_Continent=='Africa')$Origin_Continent)
unique(subset(alpha_all_replicates,Origin_Continent=='Africa')$Destination_Continent)

#Africa-Africa
africa_to_africa<-subset(subset(alpha_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='Africa')
africa_to_africa_table <- africa_to_africa %>% count(date4, replicate)
africa_to_africa_table_summarize <- africa_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))
#imports_mozb_collapse_summarise$date_week <- as.POSIXct(imports_mozb_collapse_summarise$date_week)

#Europe-Africa
europe_to_africa<-subset(subset(alpha_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='Europe')
europe_to_africa_table <- europe_to_africa %>% count(date4, replicate)
europe_to_africa_table_summarize <- europe_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))

#exports
europe_to_africa_exports<-subset(subset(alpha_all_replicates,Origin_Continent=='Africa'),Destination_Continent=='Europe')
europe_to_africa_exports_table <- europe_to_africa_exports %>% count(date4, replicate)
europe_to_africa_exports_table_summarize <- europe_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


#NAmerica-Africa
Namerica_to_africa<-subset(subset(alpha_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='North America')
Namerica_to_africa_table <- Namerica_to_africa %>% count(date4, replicate)
Namerica_to_africa_table_summarize <- Namerica_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))




cols <- c("Within\nAfrica" = "#1B9E77", "From\nEurope" = "#D95F02", "To Europe" = "#7570B3", "From\nAsia" = "#E7298A", 'To Asia' = '#66A61E', 'From North\nAmerica'='#E6AB02', 'To North\nAmerica' = '#A6761D', 'From South\nAmerica' = '#666666')



alpha_intros<-ggplot()  + theme_minimal()+
  geom_ribbon(data=africa_to_africa_table_summarize,aes(x=date4, y=mean,fill='Within\nAfrica', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=africa_to_africa_table_summarize,aes(x=date4, y=mean, color='Within\nAfrica'))+
  geom_ribbon(data=europe_to_africa_table_summarize,aes(x=date4, y=mean,fill='From\nEurope', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=europe_to_africa_table_summarize,aes(x=date4, y=mean, color='From\nEurope'))+
  geom_ribbon(data=europe_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='To Europe', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=europe_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='To Europe'),linetype='dashed')+
  geom_ribbon(data=Namerica_to_africa_table_summarize,aes(x=date4, y=mean,fill='From North\nAmerica', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=Namerica_to_africa_table_summarize,aes(x=date4, y=mean, color='From North\nAmerica'))+
  
  scale_colour_manual(values=cols, name='')+
  scale_fill_manual(values=cols, name='')+
  #scale_colour_brewer(palette='Dark2', name='', labels=c('Introduction from\nOther African\nCountries','Introduction from\nEurope', 'Export to\nEurope'))+
  #scale_fill_brewer(palette='Dark2', name='', labels=c('Introduction from\nOther African\nCountries','Introduction from\nEurope', 'Export to\nEurope'))+
  theme(legend.position = 'top', legend.title = element_text(size=10),legend.text = element_text(size=10))+
  xlab('')+
  ylab('Number of\nViral Exchanges')+
  scale_y_continuous(trans = "log10", limits = c(1,200))+
  scale_x_date(date_labels = "%b\n%Y",date_breaks = "3 months", limits=as.Date(c("2020/10/01","2021/08/01")))

alpha_intros




df_africa<-africa_metadata
df_africa$date<-as.Date(df_africa$date)

df_africa$days<-as.Date(cut(df_africa$date,breaks = "day",start.on.monday = FALSE))
df_africa$date2<-as.Date(cut(df_africa$date,breaks = "2 weeks",start.on.monday = FALSE))
df_africa$date3<-as.Date(cut(df_africa$date,breaks = "1 month",start.on.monday = FALSE))
df_africa$date<-as.Date(cut(df_africa$date,breaks = "1 week",start.on.monday = FALSE))

alpha_prevalence<-ggplot(df_africa)+ theme_minimal()+
  geom_bar(color='black', size=0.1,position='fill',mapping = aes(x=date2,fill=Nextstrain_clade=='20I (Alpha, V1)'))+
  scale_fill_manual(values=c('white','grey30'),name='Lineages', labels=c('Others','Alpha'))+
  theme(legend.position = 'top', legend.title = element_text(size=10),legend.text = element_text(size=10))+
  ylab('Genomic\nPrevalence')+
  xlab('')+
  scale_y_continuous(limits = c(0,1),breaks = c(0,0.5,1))+
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank())+
  scale_x_date(date_labels = "%b\n%Y",date_breaks = "3 months", limits=as.Date(c("2020/10/01","2021/08/01")))

#alpha_prevalence

alpha_figAB<-plot_grid(alpha_prevalence,alpha_intros,align='v',ncol=1, rel_heights = c(0.4,0.6))

#alpha_figAB


alpha_all_replicates<-alpha_all_replicates_africa_0008
africa_to_africa<-subset(subset(alpha_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='Africa')

world3 <- map_data("world")

world3<- world3 %>% 
  left_join(africa_to_africa, by = c("region" = "Destination"))

africa_to_africa$Origin_Continent_Region<-as.character(africa_to_africa$Origin_Continent_Region)

africa_to_africa<-africa_to_africa %>%
  dplyr::group_by(Origin)%>%
  dplyr::mutate(number=n())
regional_cols<-c("Eastern Africa" = "dodgerblue2", "Southern Africa" = "lightpink3", "Western Africa" = "#A4036F", "Northern Africa" = "darkblue")

alpha_africa_map<-ggplot() +
  theme_void()+
  #coord_map("gilbert")+
  geom_map(data=world3,map=world3, aes(long, lat,map_id=region), color="grey40", fill='white',size=0.2)+
  
  geom_curve(data = africa_to_africa,
             aes(x = as.double(origin_long), 
                 y = as.double(origin_lat), 
                 xend = as.double(destination_long), 
                 yend = as.double(destination_lat), colour=Origin_Continent_Region),
             size=0.8)+
  geom_point(data = africa_to_africa,
             aes(x = as.double(origin_long), y = as.double(origin_lat), fill=Origin_Continent_Region,size=number),
             color='black', shape=21)+
  scale_color_manual(values=regional_cols, name='Regions of Origin')+
  scale_fill_manual(values=regional_cols, name='Regions of Origin')+
  theme(legend.position = 'none')+
  #scale_color_brewer(palette='Dark2', name='Regions of Origin')+
  #scale_fill_brewer(palette='Dark2', name='Regions of Origin')+
  scale_x_continuous(limits = c(-20, 60))+
  scale_y_continuous(limits = c(-35, 38))


alpha_africa_map

alpha_all<-plot_grid(alpha_figAB,alpha_africa_map, ncol=1, rel_heights=c(0.55,0.45))
alpha_all

## Beta



replicate1<-read.table(file='ImportExport/Beta_Africa_focused_0.0008/1annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate1$replicate <- "1"
replicate2<-read.table(file='ImportExport/Beta_Africa_focused_0.0008/2annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate2$replicate <- "2"
replicate3<-read.table(file='ImportExport/Beta_Africa_focused_0.0008/3annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate3$replicate <- "3"
replicate4<-read.table(file='ImportExport/Beta_Africa_focused_0.0008/4annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate4$replicate <- "4"
replicate5<-read.table(file='ImportExport/Beta_Africa_focused_0.0008/5annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate5$replicate <- "5"
replicate6<-read.table(file='ImportExport/Beta_Africa_focused_0.0008/6annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate6$replicate <- "6"
replicate7<-read.table(file='ImportExport/Beta_Africa_focused_0.0008/7annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate7$replicate <- "7"
replicate8<-read.table(file='ImportExport/Beta_Africa_focused_0.0008/8annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate8$replicate <- "8"
replicate9<-read.table(file='ImportExport/Beta_Africa_focused_0.0008/9annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate9$replicate <- "9"
replicate10<-read.table(file='ImportExport/Beta_Africa_focused_0.0008/10annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate10$replicate <- "10"


beta_all_replicates<-rbind(replicate1,replicate2,replicate3,replicate4,
                           replicate5,replicate6,replicate7,replicate8,
                           replicate9,replicate10)
beta_all_replicates[beta_all_replicates == "USA"] <- "United States"
beta_all_replicates[beta_all_replicates == "Republic of the Congo"] <- "Congo (Brazzaville)"
beta_all_replicates[beta_all_replicates == "Democratic Republic of the Congo"] <- "Congo (Kinshasa)"

beta_all_replicates[beta_all_replicates == "Coted Ivoire"] <- "Ivory Coast"

beta_all_replicates<-subset(beta_all_replicates,Origin!='Reunion')
beta_all_replicates<-subset(beta_all_replicates,Origin!='Mayotte')

beta_all_replicates$date<-date_decimal(beta_all_replicates$EventTime)

beta_all_replicates$Origin_Continent<-lapply(beta_all_replicates$Origin,country2continent)
beta_all_replicates$Destination_Continent<-lapply(beta_all_replicates$Destination,country2continent)

beta_all_replicates$Origin_Continent_Region<-lapply(beta_all_replicates$Origin,country2continent_region)
beta_all_replicates$Destination_Continent_Region<-lapply(beta_all_replicates$Destination,country2continent_region)

beta_all_replicates$Variant <- "Beta"

beta_all_replicates$days<-as.Date(cut(beta_all_replicates$date,breaks = "day",start.on.monday = FALSE))
beta_all_replicates$date<-as.Date(cut(beta_all_replicates$date,breaks = "week",start.on.monday = FALSE))
beta_all_replicates$date2<-as.Date(cut(beta_all_replicates$date,breaks = "2 week",start.on.monday = FALSE))
beta_all_replicates$date4<-as.Date(cut(beta_all_replicates$date,breaks = "1 month",start.on.monday = FALSE))


beta_all_replicates$destination_lat<- lapply(beta_all_replicates$Destination,country2lat)
beta_all_replicates$destination_long<- lapply(beta_all_replicates$Destination,country2long)

beta_all_replicates$origin_lat<- lapply(beta_all_replicates$Origin,country2lat)
beta_all_replicates$origin_long<- lapply(beta_all_replicates$Origin,country2long)

beta_all_replicates_africa_0008<-beta_all_replicates

replicate1<-read.table(file='ImportExport/Beta_0.0008/africa_seed1344_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate1$replicate <- "1"
replicate2<-read.table(file='ImportExport/Beta_0.0008/africa_seed2007_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate2$replicate <- "2"
replicate3<-read.table(file='ImportExport/Beta_0.0008/africa_seed2099_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate3$replicate <- "3"
replicate4<-read.table(file='ImportExport/Beta_0.0008/africa_seed3278_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate4$replicate <- "4"
replicate5<-read.table(file='ImportExport/Beta_0.0008/africa_seed3500_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate5$replicate <- "5"
replicate6<-read.table(file='ImportExport/Beta_0.0008/africa_seed3989_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate6$replicate <- "6"
replicate7<-read.table(file='ImportExport/Beta_0.0008/africa_seed4034_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate7$replicate <- "7"
replicate8<-read.table(file='ImportExport/Beta_0.0008/africa_seed4704_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate8$replicate <- "8"
replicate9<-read.table(file='ImportExport/Beta_0.0008/africa_seed5342_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate9$replicate <- "9"
replicate10<-read.table(file='ImportExport/Beta_0.0008/africa_seed6767_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate10$replicate <- "10"


beta_all_replicates<-rbind(replicate1,replicate2,replicate3,replicate4,
                           replicate5,replicate6,replicate7,replicate8,
                           replicate9,replicate10)
beta_all_replicates[beta_all_replicates == "USA"] <- "United States"
beta_all_replicates[beta_all_replicates == "Republic of the Congo"] <- "Congo (Brazzaville)"
beta_all_replicates[beta_all_replicates == "Democratic Republic of the Congo"] <- "Congo (Kinshasa)"

beta_all_replicates[beta_all_replicates == "Coted Ivoire"] <- "Ivory Coast"

beta_all_replicates<-subset(beta_all_replicates,Origin!='Reunion')
beta_all_replicates<-subset(beta_all_replicates,Origin!='Mayotte')

beta_all_replicates$date<-date_decimal(beta_all_replicates$EventTime)

beta_all_replicates$Origin_Continent<-lapply(beta_all_replicates$Origin,country2continent)
beta_all_replicates$Destination_Continent<-lapply(beta_all_replicates$Destination,country2continent)

beta_all_replicates$Origin_Continent_Region<-lapply(beta_all_replicates$Origin,country2continent_region)
beta_all_replicates$Destination_Continent_Region<-lapply(beta_all_replicates$Destination,country2continent_region)

beta_all_replicates$Variant <- "Beta"

beta_all_replicates$days<-as.Date(cut(beta_all_replicates$date,breaks = "day",start.on.monday = FALSE))
beta_all_replicates$date<-as.Date(cut(beta_all_replicates$date,breaks = "week",start.on.monday = FALSE))
beta_all_replicates$date2<-as.Date(cut(beta_all_replicates$date,breaks = "2 week",start.on.monday = FALSE))
beta_all_replicates$date4<-as.Date(cut(beta_all_replicates$date,breaks = "1 month",start.on.monday = FALSE))


beta_all_replicates$destination_lat<- lapply(beta_all_replicates$Destination,country2lat)
beta_all_replicates$destination_long<- lapply(beta_all_replicates$Destination,country2long)

beta_all_replicates$origin_lat<- lapply(beta_all_replicates$Origin,country2lat)
beta_all_replicates$origin_long<- lapply(beta_all_replicates$Origin,country2long)

beta_all_replicates_global_0008<-beta_all_replicates

beta_all_replicates<-beta_all_replicates_global_0008

unique(subset(beta_all_replicates,Destination_Continent=='Africa')$Origin_Continent_Region)
unique(subset(beta_all_replicates,Destination_Continent=='Africa')$Origin_Continent)
unique(subset(beta_all_replicates,Origin_Continent=='Africa')$Destination_Continent)

#Africa-Africa
africa_to_africa<-subset(subset(beta_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='Africa')
africa_to_africa_table <- africa_to_africa %>% count(date4, replicate)
africa_to_africa_table_summarize <- africa_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))
#imports_mozb_collapse_summarise$date_week <- as.POSIXct(imports_mozb_collapse_summarise$date_week)

#Europe-Africa
europe_to_africa<-subset(subset(beta_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='Europe')
europe_to_africa_table <- europe_to_africa %>% count(date4, replicate)
europe_to_africa_table_summarize <- europe_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))

#exports
europe_to_africa_exports<-subset(subset(beta_all_replicates,Origin_Continent=='Africa'),Destination_Continent=='Europe')
europe_to_africa_exports_table <- europe_to_africa_exports %>% count(date4, replicate)
europe_to_africa_exports_table_summarize <- europe_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


#NAmerica-Africa
Namerica_to_africa<-subset(subset(beta_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='North America')
Namerica_to_africa_table <- Namerica_to_africa %>% count(date4, replicate)
Namerica_to_africa_table_summarize <- Namerica_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))

#exports
Namerica_to_africa_exports<-subset(subset(beta_all_replicates,Origin_Continent=='Africa'),Destination_Continent=='North America')
Namerica_to_africa_exports_table <- Namerica_to_africa_exports %>% count(date4, replicate)
Namerica_to_africa_exports_table_summarize <- Namerica_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


#Asia-Africa
asia_to_africa<-subset(subset(beta_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='Asia')
asia_to_africa_table <- asia_to_africa %>% count(date4, replicate)
asia_to_africa_table_summarize <- asia_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


#Asia-Africa
asia_to_africa_exports<-subset(subset(beta_all_replicates,Origin_Continent=='Africa'),Destination_Continent=='Asia')
asia_to_africa_exports_table <- asia_to_africa_exports %>% count(date4, replicate)
asia_to_africa_exports_table_summarize <- asia_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


#SAmerica-Africa
Samerica_to_africa_exports<-subset(subset(beta_all_replicates,Origin_Continent=='Africa'),Destination_Continent=='South America')
Samerica_to_africa_exports_table <- Samerica_to_africa_exports %>% count(date4, replicate)
Samerica_to_africa_exports_table_summarize <- Samerica_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))



#Australia-Africa
australia_to_africa_exports<-subset(subset(beta_all_replicates,Origin_Continent=='Africa'),Destination_Continent=='Australia')
australia_to_africa_exports_table <- australia_to_africa_exports %>% count(date4, replicate)
australia_to_africa_exports_table_summarize <- australia_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


beta_intros<-ggplot()  + theme_minimal()+
  geom_ribbon(data=africa_to_africa_table_summarize,aes(x=date4, y=mean,fill='Within\nAfrica', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=africa_to_africa_table_summarize,aes(x=date4, y=mean, color='Within\nAfrica'))+
  geom_ribbon(data=europe_to_africa_table_summarize,aes(x=date4, y=mean,fill='From\nEurope', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=europe_to_africa_table_summarize,aes(x=date4, y=mean, color='From\nEurope'))+
  
  geom_ribbon(data=europe_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='To Europe', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=europe_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='To Europe'),linetype='dashed')+
  
  geom_ribbon(data=Namerica_to_africa_table_summarize,aes(x=date4, y=mean,fill='From North\nAmerica', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=Namerica_to_africa_table_summarize,aes(x=date4, y=mean, color='From North\nAmerica'))+
  geom_ribbon(data=Namerica_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='To North\nAmerica', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=Namerica_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='To North\nAmerica'), linetype='dashed')+
  
  geom_ribbon(data=asia_to_africa_table_summarize,aes(x=date4, y=mean,fill='From\nAsia', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=asia_to_africa_table_summarize,aes(x=date4, y=mean, color='From\nAsia'))+
  geom_ribbon(data=asia_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='To Asia', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=asia_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='To Asia'), linetype='dashed')+
  
  #geom_ribbon(data=Samerica_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='to South America', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  #geom_line(data=Samerica_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='to South America'), linetype='dashed')+
  
  
  #geom_ribbon(data=australia_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='to Australia', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  #geom_line(data=australia_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='to Australia'), linetype='dashed')+
  scale_colour_manual(values=cols,name='')+
  scale_fill_manual(values=cols,name='')+
  #scale_colour_brewer(palette='Dark2', name='')+
  #scale_fill_brewer(palette='Dark2', name='')+
  theme(legend.position = 'top', legend.title = element_text(size=10),legend.text = element_text(size=10))+
  xlab('')+
  ylab('Number of\nViral Exchanges')+
  scale_y_continuous(trans = "log10", limits = c(1,200))+
  scale_x_date(date_labels = "%b\n%Y",date_breaks = "3 months", limits=as.Date(c("2020/08/01","2021/07/31")))

beta_intros


df_africa<-africa_metadata
df_africa$date<-as.Date(df_africa$date)

df_africa$days<-as.Date(cut(df_africa$date,breaks = "day",start.on.monday = FALSE))
df_africa$date2<-as.Date(cut(df_africa$date,breaks = "2 weeks",start.on.monday = FALSE))
df_africa$date3<-as.Date(cut(df_africa$date,breaks = "1 month",start.on.monday = FALSE))
df_africa$date<-as.Date(cut(df_africa$date,breaks = "1 week",start.on.monday = FALSE))

beta_prevalence<-ggplot(df_africa)+ theme_minimal()+
  geom_bar(color='black', size=0.1,position='fill',mapping = aes(x=date2,fill=Nextstrain_clade=='20H (Beta, V2)'))+
  scale_fill_manual(values=c('white','grey30'),name='Lineages', labels=c('Others','Beta'))+
  theme(legend.position = 'top', legend.title = element_text(size=10),legend.text = element_text(size=10))+
  ylab('Genomic\nPrevalence')+
  xlab('')+
  scale_y_continuous(limits = c(0,1),breaks = c(0,0.5,1))+
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank())+
  scale_x_date(date_labels = "%b\n%Y",date_breaks = "3 months", limits=as.Date(c("2020/08/01","2021/07/31")))

beta_prevalence

beta_FigAB<-plot_grid(beta_prevalence,beta_intros,align='v',ncol=1, rel_heights = c(0.4,0.6))
beta_FigAB

beta_all_replicates<-beta_all_replicates_africa_0008
africa_to_africa<-subset(subset(beta_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='Africa')

world3 <- map_data("world")

world3<- world3 %>% 
  left_join(africa_to_africa, by = c("region" = "Destination"))

africa_to_africa$Origin_Continent_Region<-as.character(africa_to_africa$Origin_Continent_Region)

africa_to_africa<-africa_to_africa %>%
  dplyr::group_by(Origin)%>%
  dplyr::mutate(number=n())

#regional_cols<-c("Eastern Africa" = "#1b9e77", "Southern Africa" = "#d95f02", "Western Africa" = "#7570b3", "Northern Africa" = "#e7298a")

beta_africa_map<-ggplot() +
  theme_void()+
  #coord_map("gilbert")+
  geom_map(data=world3,map=world3, aes(long, lat,map_id=region), color="grey40", fill='white',size=0.2)+
  
  geom_curve(data = africa_to_africa,
             aes(x = as.double(origin_long), 
                 y = as.double(origin_lat), 
                 xend = as.double(destination_long), 
                 yend = as.double(destination_lat), colour=Origin_Continent_Region),
             size=0.8)+
  geom_point(data = africa_to_africa,
             aes(x = as.double(origin_long), y = as.double(origin_lat), fill=Origin_Continent_Region,size=number),
             color='black', shape=21)+
  scale_color_manual(values=regional_cols, name='Regions of Origin')+
  scale_fill_manual(values=regional_cols, name='Regions of Origin')+
  theme(legend.position = 'none')+
  #scale_color_brewer(palette='Dark2', name='Regions of Origin')+
  #scale_fill_brewer(palette='Dark2', name='Regions of Origin')+
  scale_x_continuous(limits = c(-20, 60))+
  scale_y_continuous(limits = c(-35, 38))


beta_africa_map

beta_all<-plot_grid(beta_FigAB,beta_africa_map, ncol=1, rel_heights=c(0.55,0.45))
beta_all

## Delta


replicate1<-read.table(file='ImportExport/Delta_Africa_focused_0.0008/1annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate1$replicate <- "1"
replicate2<-read.table(file='ImportExport/Delta_Africa_focused_0.0008/2annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate2$replicate <- "2"
replicate3<-read.table(file='ImportExport/Delta_Africa_focused_0.0008/3annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate3$replicate <- "3"
replicate4<-read.table(file='ImportExport/Delta_Africa_focused_0.0008/4annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate4$replicate <- "4"
replicate5<-read.table(file='ImportExport/Delta_Africa_focused_0.0008/5annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate5$replicate <- "5"
replicate6<-read.table(file='ImportExport/Delta_Africa_focused_0.0008/6annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate6$replicate <- "6"
replicate7<-read.table(file='ImportExport/Delta_Africa_focused_0.0008/7annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate7$replicate <- "7"
replicate8<-read.table(file='ImportExport/Delta_Africa_focused_0.0008/8annottated_tree_events.csv.csv', sep = '\t', header = TRUE)
replicate8$replicate <- "8"
replicate9<-read.table(file='ImportExport/Delta_Africa_focused_0.0008/9annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate9$replicate <- "9"
replicate10<-read.table(file='ImportExport/Delta_Africa_focused_0.0008/10annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate10$replicate <- "10"


delta_all_replicates<-rbind(replicate1,replicate2,replicate3,replicate4,
                            replicate5,replicate6,replicate7,replicate8,
                            replicate9,replicate10)
delta_all_replicates[delta_all_replicates == "USA"] <- "United States"
delta_all_replicates[delta_all_replicates == "Republic of the Congo"] <- "Congo (Brazzaville)"
delta_all_replicates[delta_all_replicates == "Democratic Republic of the Congo"] <- "Congo (Kinshasa)"

delta_all_replicates[delta_all_replicates == "Coted Ivoire"] <- "Ivory Coast"

delta_all_replicates<-subset(delta_all_replicates,Origin!='Reunion')
delta_all_replicates<-subset(delta_all_replicates,Origin!='Mayotte')

delta_all_replicates$date<-date_decimal(delta_all_replicates$EventTime)

delta_all_replicates$Origin_Continent<-lapply(delta_all_replicates$Origin,country2continent)
delta_all_replicates$Destination_Continent<-lapply(delta_all_replicates$Destination,country2continent)

delta_all_replicates$Origin_Continent_Region<-lapply(delta_all_replicates$Origin,country2continent_region)
delta_all_replicates$Destination_Continent_Region<-lapply(delta_all_replicates$Destination,country2continent_region)

delta_all_replicates$Variant <- "Delta"

delta_all_replicates$days<-as.Date(cut(delta_all_replicates$date,breaks = "day",start.on.monday = FALSE))
delta_all_replicates$date<-as.Date(cut(delta_all_replicates$date,breaks = "week",start.on.monday = FALSE))
delta_all_replicates$date2<-as.Date(cut(delta_all_replicates$date,breaks = "2 week",start.on.monday = FALSE))
delta_all_replicates$date4<-as.Date(cut(delta_all_replicates$date,breaks = "1 month",start.on.monday = FALSE))


delta_all_replicates$destination_lat<- lapply(delta_all_replicates$Destination,country2lat)
delta_all_replicates$destination_long<- lapply(delta_all_replicates$Destination,country2long)

delta_all_replicates$origin_lat<- lapply(delta_all_replicates$Origin,country2lat)
delta_all_replicates$origin_long<- lapply(delta_all_replicates$Origin,country2long)

delta_all_replicates_africa_0008<-delta_all_replicates


replicate1<-read.table(file='ImportExport/Delta_0.0008/africa/delta0546_africa_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate1$replicate <- "1"
replicate2<-read.table(file='ImportExport/Delta_0.0008/africa/delta1321_africa_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate2$replicate <- "2"
replicate3<-read.table(file='ImportExport/Delta_0.0008/africa/delta2765_africa_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate3$replicate <- "3"
replicate4<-read.table(file='ImportExport/Delta_0.0008/africa/delta3876_africa_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate4$replicate <- "4"
replicate5<-read.table(file='ImportExport/Delta_0.0008/africa/delta4012_africa_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate5$replicate <- "5"
replicate6<-read.table(file='ImportExport/Delta_0.0008/africa/delta5555_africa_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate6$replicate <- "6"
replicate7<-read.table(file='ImportExport/Delta_0.0008/africa/delta6667_africa_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate7$replicate <- "7"
replicate8<-read.table(file='ImportExport/Delta_0.0008/africa/delta7776_africa_annottated_tree_events copy.csv', sep = '\t', header = TRUE)
replicate8$replicate <- "8"
replicate9<-read.table(file='ImportExport/Delta_0.0008/africa/delta8878_africa_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate9$replicate <- "9"
replicate10<-read.table(file='ImportExport/Delta_0.0008/africa/delta9898_africa_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate10$replicate <- "10"


delta_all_replicates<-rbind(replicate1,replicate2,replicate3,replicate4,
                            replicate5,replicate6,replicate7,replicate8,
                            replicate9,replicate10)
delta_all_replicates[delta_all_replicates == "USA"] <- "United States"
delta_all_replicates[delta_all_replicates == "Republic of the Congo"] <- "Congo (Brazzaville)"
delta_all_replicates[delta_all_replicates == "Democratic Republic of the Congo"] <- "Congo (Kinshasa)"

delta_all_replicates[delta_all_replicates == "Coted Ivoire"] <- "Ivory Coast"

delta_all_replicates<-subset(delta_all_replicates,Origin!='Reunion')
delta_all_replicates<-subset(delta_all_replicates,Origin!='Mayotte')

delta_all_replicates$date<-date_decimal(delta_all_replicates$EventTime)

delta_all_replicates$Origin_Continent<-lapply(delta_all_replicates$Origin,country2continent)
delta_all_replicates$Destination_Continent<-lapply(delta_all_replicates$Destination,country2continent)

delta_all_replicates$Origin_Continent_Region<-lapply(delta_all_replicates$Origin,country2continent_region)
delta_all_replicates$Destination_Continent_Region<-lapply(delta_all_replicates$Destination,country2continent_region)

delta_all_replicates$Variant <- "Delta"

delta_all_replicates$days<-as.Date(cut(delta_all_replicates$date,breaks = "day",start.on.monday = FALSE))
delta_all_replicates$date<-as.Date(cut(delta_all_replicates$date,breaks = "week",start.on.monday = FALSE))
delta_all_replicates$date2<-as.Date(cut(delta_all_replicates$date,breaks = "2 week",start.on.monday = FALSE))
delta_all_replicates$date4<-as.Date(cut(delta_all_replicates$date,breaks = "1 month",start.on.monday = FALSE))


delta_all_replicates$destination_lat<- lapply(delta_all_replicates$Destination,country2lat)
delta_all_replicates$destination_long<- lapply(delta_all_replicates$Destination,country2long)

delta_all_replicates$origin_lat<- lapply(delta_all_replicates$Origin,country2lat)
delta_all_replicates$origin_long<- lapply(delta_all_replicates$Origin,country2long)

delta_all_replicates_global_0008<-delta_all_replicates

delta_all_replicates<-delta_all_replicates_global_0008

unique(subset(delta_all_replicates,Destination_Continent=='Africa')$Origin_Continent_Region)
unique(subset(delta_all_replicates,Destination_Continent=='Africa')$Origin_Continent)
unique(subset(delta_all_replicates,Origin_Continent=='Africa')$Destination_Continent)

#Africa-Africa
africa_to_africa<-subset(subset(delta_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='Africa')
africa_to_africa_table <- africa_to_africa %>% count(date4, replicate)
africa_to_africa_table_summarize <- africa_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))
#imports_mozb_collapse_summarise$date_week <- as.POSIXct(imports_mozb_collapse_summarise$date_week)

#Europe-Africa
europe_to_africa<-subset(subset(delta_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='Europe')
europe_to_africa_table <- europe_to_africa %>% count(date4, replicate)
europe_to_africa_table_summarize <- europe_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))

#exports
europe_to_africa_exports<-subset(subset(delta_all_replicates,Origin_Continent=='Africa'),Destination_Continent=='Europe')
europe_to_africa_exports_table <- europe_to_africa_exports %>% count(date4, replicate)
europe_to_africa_exports_table_summarize <- europe_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


#NAmerica-Africa
Namerica_to_africa<-subset(subset(delta_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='North America')
Namerica_to_africa_table <- Namerica_to_africa %>% count(date4, replicate)
Namerica_to_africa_table_summarize <- Namerica_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))

#exports
Namerica_to_africa_exports<-subset(subset(delta_all_replicates,Origin_Continent=='Africa'),Destination_Continent=='North America')
Namerica_to_africa_exports_table <- Namerica_to_africa_exports %>% count(date4, replicate)
Namerica_to_africa_exports_table_summarize <- Namerica_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


#Asia-Africa
asia_to_africa<-subset(subset(delta_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='Asia')
asia_to_africa_table <- asia_to_africa %>% count(date4, replicate)
asia_to_africa_table_summarize <- asia_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


#Asia-Africa
asia_to_africa_exports<-subset(subset(delta_all_replicates,Destination_Continent=='Asia'),Origin_Continent=='Africa')
asia_to_africa_exports_table <- asia_to_africa_exports %>% count(date4, replicate)
asia_to_africa_exports_table_summarize <- asia_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


#SAmerica-Africa

Samerica_to_africa<-subset(subset(delta_all_replicates,Origin_Continent=='South America'),Destination_Continent=='Africa')
Samerica_to_africa_table <- Samerica_to_africa %>% count(date4, replicate)
Samerica_to_africa_table_summarize <- Samerica_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))

Samerica_to_africa_exports<-subset(subset(delta_all_replicates,Origin_Continent=='Africa'),Destination_Continent=='South America')
Samerica_to_africa_exports_table <- Samerica_to_africa_exports %>% count(date4, replicate)
Samerica_to_africa_exports_table_summarize <- Samerica_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))



#Australia-Africa
australia_to_africa_exports<-subset(subset(delta_all_replicates,Origin_Continent=='Africa'),Destination_Continent=='Australia')
australia_to_africa_exports_table <- australia_to_africa_exports %>% count(date4, replicate)
australia_to_africa_exports_table_summarize <- australia_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


delta_intros<-ggplot()  + theme_minimal()+
  geom_ribbon(data=africa_to_africa_table_summarize,aes(x=date4, y=mean,fill='Within\nAfrica', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=africa_to_africa_table_summarize,aes(x=date4, y=mean, color='Within\nAfrica'))+
  geom_ribbon(data=europe_to_africa_table_summarize,aes(x=date4, y=mean,fill='From\nEurope', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=europe_to_africa_table_summarize,aes(x=date4, y=mean, color='From\nEurope'))+
  
  geom_ribbon(data=europe_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='To Europe', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=europe_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='To Europe'),linetype='dashed')+
  
  #geom_ribbon(data=Namerica_to_africa_table_summarize,aes(x=date4, y=mean,fill='From North\nAmerica', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  #geom_line(data=Namerica_to_africa_table_summarize,aes(x=date4, y=mean, color='From North\nAmerica'))+
  #geom_ribbon(data=Namerica_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='To North\nAmerica', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  #geom_line(data=Namerica_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='To North\nAmerica'), linetype='dashed')+
  
  geom_ribbon(data=asia_to_africa_table_summarize,aes(x=date4, y=mean,fill='From\nAsia', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=asia_to_africa_table_summarize,aes(x=date4, y=mean, color='From\nAsia'))+
  #geom_ribbon(data=asia_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='To Asia', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  #geom_line(data=asia_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='To Asia'), linetype='dashed')+
  
  #geom_ribbon(data=Samerica_to_africa_table_summarize,aes(x=date4, y=mean,fill='From South\nAmerica', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  #geom_line(data=Samerica_to_africa_table_summarize,aes(x=date4, y=mean, color='From South\nAmerica'))+
  
  #geom_ribbon(data=Samerica_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='to South America', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  #geom_line(data=Samerica_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='to South America'), linetype='dashed')+
  
  
  #geom_ribbon(data=australia_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='to Australia', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
#geom_line(data=australia_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='to Australia'), linetype='dashed')+
scale_colour_manual(values=cols,name='')+
  scale_fill_manual(values=cols,name='')+
  #scale_colour_brewer(palette='Dark2', name='')+
  #scale_fill_brewer(palette='Dark2', name='')+
  theme(legend.position = 'top', legend.title = element_text(size=10),legend.text = element_text(size=10))+
  xlab('')+
  ylab('Number of\nViral Exchanges')+
  scale_y_continuous(trans = "log10", limits = c(1,200))+
  
  scale_x_date(date_labels = "%b\n%Y",date_breaks = "3 months", limits=as.Date(c("2021/01/01","2021/10/30")))

delta_intros


df_africa<-africa_metadata
df_africa$date<-as.Date(df_africa$date)

df_africa$days<-as.Date(cut(df_africa$date,breaks = "day",start.on.monday = FALSE))
df_africa$date2<-as.Date(cut(df_africa$date,breaks = "2 weeks",start.on.monday = FALSE))
df_africa$date3<-as.Date(cut(df_africa$date,breaks = "1 month",start.on.monday = FALSE))
df_africa$date<-as.Date(cut(df_africa$date,breaks = "1 week",start.on.monday = FALSE))

delta_prevalence<-ggplot(df_africa)+ theme_minimal()+
  geom_bar(color='black', size=0.1,position='fill',mapping = aes(x=date2,fill=Nextstrain_clade %like% 'Delta'))+
  scale_fill_manual(values=c('white','grey30'),name='Lineages', labels=c('Others','Delta'))+
  theme(legend.position = 'top', legend.title = element_text(size=10),legend.text = element_text(size=10))+
  ylab('Genomic\nPrevalence')+
  xlab('')+
  scale_y_continuous(limits = c(0,1),breaks = c(0,0.5,1))+
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank())+
  scale_x_date(date_labels = "%b\n%Y",date_breaks = "3 months", limits=as.Date(c("2021/01/01","2021/10/30")))

delta_prevalence

delta_FigAB<-plot_grid(delta_prevalence,delta_intros,align='v',ncol=1, rel_heights = c(0.4,0.6))
delta_FigAB


delta_all_replicates<-delta_all_replicates_africa_0008
africa_to_africa<-subset(subset(delta_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='Africa')

world3 <- map_data("world")

world3<- world3 %>% 
  left_join(africa_to_africa, by = c("region" = "Destination"))

africa_to_africa$Origin_Continent_Region<-as.character(africa_to_africa$Origin_Continent_Region)

africa_to_africa<-africa_to_africa %>%
  dplyr::group_by(Origin)%>%
  dplyr::mutate(number=n())
#regional_cols<-c("Eastern Africa" = "#1b9e77", "Southern Africa" = "#d95f02", "Western Africa" = "#7570b3", "Northern Africa" = "#e7298a")

delta_africa_map<-ggplot() +
  theme_void()+
  #coord_map("gilbert")+
  geom_map(data=world3,map=world3, aes(long, lat,map_id=region), color="grey40", fill='white',size=0.2)+
  
  geom_curve(data = africa_to_africa,
             aes(x = as.double(origin_long), 
                 y = as.double(origin_lat), 
                 xend = as.double(destination_long), 
                 yend = as.double(destination_lat), colour=Origin_Continent_Region),
             size=0.8)+
  geom_point(data = africa_to_africa,
             aes(x = as.double(origin_long), y = as.double(origin_lat), fill=Origin_Continent_Region,size=number),
             color='black', shape=21)+
  scale_color_manual(values=regional_cols, name='Regions of Origin')+
  scale_fill_manual(values=regional_cols, name='Regions of Origin')+
  theme(legend.position = 'none')+
  #scale_color_brewer(palette='Dark2', name='Regions of Origin')+
  #scale_fill_brewer(palette='Dark2', name='Regions of Origin')+
  scale_x_continuous(limits = c(-20, 60))+
  scale_y_continuous(limits = c(-35, 38))


delta_africa_map

delta_all<-plot_grid(delta_FigAB,delta_africa_map, ncol=1, rel_heights=c(0.55,0.45))
delta_all


## Omicron BA.1


replicate1<-read.table(file='ImportExport/BA1_Africa_focused_0.0008/1annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate1$replicate <- "1"
replicate2<-read.table(file='ImportExport/BA1_Africa_focused_0.0008/2annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate2$replicate <- "2"
replicate3<-read.table(file='ImportExport/BA1_Africa_focused_0.0008/3annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate3$replicate <- "3"
replicate4<-read.table(file='ImportExport/BA1_Africa_focused_0.0008/4annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate4$replicate <- "4"
replicate5<-read.table(file='ImportExport/BA1_Africa_focused_0.0008/5annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate5$replicate <- "5"
replicate6<-read.table(file='ImportExport/BA1_Africa_focused_0.0008/6annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate6$replicate <- "6"
replicate7<-read.table(file='ImportExport/BA1_Africa_focused_0.0008/7annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate7$replicate <- "7"
replicate8<-read.table(file='ImportExport/BA1_Africa_focused_0.0008/8annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate8$replicate <- "8"
replicate9<-read.table(file='ImportExport/BA1_Africa_focused_0.0008/9annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate9$replicate <- "9"
replicate10<-read.table(file='ImportExport/BA1_Africa_focused_0.0008/10annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate10$replicate <- "10"


omicron_all_replicates<-rbind(replicate1,replicate2,replicate3,replicate4,
                              replicate5,replicate6,replicate7,replicate8,
                              replicate9,replicate10)
omicron_all_replicates[omicron_all_replicates == "USA"] <- "United States"
omicron_all_replicates[omicron_all_replicates == "Republic of the Congo"] <- "Congo (Brazzaville)"
omicron_all_replicates[omicron_all_replicates == "Democratic Republic of the Congo"] <- "Congo (Kinshasa)"

omicron_all_replicates[omicron_all_replicates == "Coted Ivoire"] <- "Ivory Coast"

omicron_all_replicates<-subset(omicron_all_replicates,Origin!='Reunion')
omicron_all_replicates<-subset(omicron_all_replicates,Origin!='Mayotte')

omicron_all_replicates$date<-date_decimal(omicron_all_replicates$EventTime)

omicron_all_replicates$Origin_Continent<-lapply(omicron_all_replicates$Origin,country2continent)
omicron_all_replicates$Destination_Continent<-lapply(omicron_all_replicates$Destination,country2continent)

omicron_all_replicates$Origin_Continent_Region<-lapply(omicron_all_replicates$Origin,country2continent_region)
omicron_all_replicates$Destination_Continent_Region<-lapply(omicron_all_replicates$Destination,country2continent_region)

omicron_all_replicates$Variant <- "Omicron"

omicron_all_replicates$days<-as.Date(cut(omicron_all_replicates$date,breaks = "day",start.on.monday = FALSE))
omicron_all_replicates$date<-as.Date(cut(omicron_all_replicates$date,breaks = "week",start.on.monday = FALSE))
omicron_all_replicates$date2<-as.Date(cut(omicron_all_replicates$date,breaks = "2 week",start.on.monday = FALSE))
omicron_all_replicates$date4<-as.Date(cut(omicron_all_replicates$date,breaks = "1 month",start.on.monday = FALSE))


omicron_all_replicates$destination_lat<- lapply(omicron_all_replicates$Destination,country2lat)
omicron_all_replicates$destination_long<- lapply(omicron_all_replicates$Destination,country2long)

omicron_all_replicates$origin_lat<- lapply(omicron_all_replicates$Origin,country2lat)
omicron_all_replicates$origin_long<- lapply(omicron_all_replicates$Origin,country2long)

omicron_all_replicates_africa_0008<-omicron_all_replicates

replicate1<-read.table(file='ImportExport/BA1_0.0008/africa/africa_seed0987_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate1$replicate <- "1"
replicate2<-read.table(file='ImportExport/BA1_0.0008/africa/africa_seed1098_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate2$replicate <- "2"
replicate3<-read.table(file='ImportExport/BA1_0.0008/africa/africa_seed2109_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate3$replicate <- "3"
replicate4<-read.table(file='ImportExport/BA1_0.0008/africa/africa_seed3210_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate4$replicate <- "4"
replicate5<-read.table(file='ImportExport/BA1_0.0008/africa/africa_seed4321_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate5$replicate <- "5"
replicate6<-read.table(file='ImportExport/BA1_0.0008/africa/africa_seed5432_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate6$replicate <- "6"
replicate7<-read.table(file='ImportExport/BA1_0.0008/africa/africa_seed6543_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate7$replicate <- "7"
replicate8<-read.table(file='ImportExport/BA1_0.0008/africa/africa_seed7654_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate8$replicate <- "8"
replicate9<-read.table(file='ImportExport/BA1_0.0008/africa/africa_seed8765_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate9$replicate <- "9"
replicate10<-read.table(file='ImportExport/BA1_0.0008/africa/africa_seed9876_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate10$replicate <- "10"


omicron_all_replicates<-rbind(replicate1,replicate2,replicate3,replicate4,
                              replicate5,replicate6,replicate7,replicate8,
                              replicate9,replicate10)
omicron_all_replicates[omicron_all_replicates == "USA"] <- "United States"
omicron_all_replicates[omicron_all_replicates == "Republic of the Congo"] <- "Congo (Brazzaville)"
omicron_all_replicates[omicron_all_replicates == "Democratic Republic of the Congo"] <- "Congo (Kinshasa)"

omicron_all_replicates[omicron_all_replicates == "Coted Ivoire"] <- "Ivory Coast"

omicron_all_replicates<-subset(omicron_all_replicates,Origin!='Reunion')
omicron_all_replicates<-subset(omicron_all_replicates,Origin!='Mayotte')

omicron_all_replicates$date<-date_decimal(omicron_all_replicates$EventTime)

omicron_all_replicates$Origin_Continent<-lapply(omicron_all_replicates$Origin,country2continent)
omicron_all_replicates$Destination_Continent<-lapply(omicron_all_replicates$Destination,country2continent)

omicron_all_replicates$Origin_Continent_Region<-lapply(omicron_all_replicates$Origin,country2continent_region)
omicron_all_replicates$Destination_Continent_Region<-lapply(omicron_all_replicates$Destination,country2continent_region)

omicron_all_replicates$Variant <- "Omicron"

omicron_all_replicates$days<-as.Date(cut(omicron_all_replicates$date,breaks = "day",start.on.monday = FALSE))
omicron_all_replicates$date<-as.Date(cut(omicron_all_replicates$date,breaks = "week",start.on.monday = FALSE))
omicron_all_replicates$date2<-as.Date(cut(omicron_all_replicates$date,breaks = "2 week",start.on.monday = FALSE))
omicron_all_replicates$date4<-as.Date(cut(omicron_all_replicates$date,breaks = "1 month",start.on.monday = FALSE))


omicron_all_replicates$destination_lat<- lapply(omicron_all_replicates$Destination,country2lat)
omicron_all_replicates$destination_long<- lapply(omicron_all_replicates$Destination,country2long)

omicron_all_replicates$origin_lat<- lapply(omicron_all_replicates$Origin,country2lat)
omicron_all_replicates$origin_long<- lapply(omicron_all_replicates$Origin,country2long)

omicron_all_replicates_global_0008<-omicron_all_replicates

omicron_all_replicates<-omicron_all_replicates_global_0008


unique(subset(omicron_all_replicates,Destination_Continent=='Africa')$Origin_Continent_Region)
unique(subset(omicron_all_replicates,Destination_Continent=='Africa')$Origin_Continent)
unique(subset(omicron_all_replicates,Origin_Continent=='Africa')$Destination_Continent)

#Africa-Africa
africa_to_africa<-subset(subset(omicron_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='Africa')
africa_to_africa_table <- africa_to_africa %>% count(date4, replicate)
africa_to_africa_table_summarize <- africa_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))
#imports_mozb_collapse_summarise$date_week <- as.POSIXct(imports_mozb_collapse_summarise$date_week)

#Europe-Africa
europe_to_africa<-subset(subset(omicron_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='Europe')
europe_to_africa_table <- europe_to_africa %>% count(date4, replicate)
europe_to_africa_table_summarize <- europe_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))

#exports
europe_to_africa_exports<-subset(subset(omicron_all_replicates,Origin_Continent=='Africa'),Destination_Continent=='Europe')
europe_to_africa_exports_table <- europe_to_africa_exports %>% count(date4, replicate)
europe_to_africa_exports_table_summarize <- europe_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


#NAmerica-Africa
Namerica_to_africa<-subset(subset(omicron_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='North America')
Namerica_to_africa_table <- Namerica_to_africa %>% count(date4, replicate)
Namerica_to_africa_table_summarize <- Namerica_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))

#exports
Namerica_to_africa_exports<-subset(subset(omicron_all_replicates,Origin_Continent=='Africa'),Destination_Continent=='North America')
Namerica_to_africa_exports_table <- Namerica_to_africa_exports %>% count(date4, replicate)
Namerica_to_africa_exports_table_summarize <- Namerica_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


#Asia-Africa
asia_to_africa<-subset(subset(omicron_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='Asia')
asia_to_africa_table <- asia_to_africa %>% count(date4, replicate)
asia_to_africa_table_summarize <- asia_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


#Asia-Africa
asia_to_africa_exports<-subset(subset(omicron_all_replicates,Destination_Continent=='Asia'),Origin_Continent=='Africa')
asia_to_africa_exports_table <- asia_to_africa_exports %>% count(date4, replicate)
asia_to_africa_exports_table_summarize <- asia_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


#SAmerica-Africa

Samerica_to_africa<-subset(subset(omicron_all_replicates,Origin_Continent=='South America'),Destination_Continent=='Africa')
Samerica_to_africa_table <- Samerica_to_africa %>% count(date4, replicate)
Samerica_to_africa_table_summarize <- Samerica_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))

Samerica_to_africa_exports<-subset(subset(omicron_all_replicates,Origin_Continent=='Africa'),Destination_Continent=='South America')
Samerica_to_africa_exports_table <- Samerica_to_africa_exports %>% count(date4, replicate)
Samerica_to_africa_exports_table_summarize <- Samerica_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))



#Australia-Africa
australia_to_africa_exports<-subset(subset(omicron_all_replicates,Origin_Continent=='Africa'),Destination_Continent=='Australia')
australia_to_africa_exports_table <- australia_to_africa_exports %>% count(date4, replicate)
australia_to_africa_exports_table_summarize <- australia_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


omicron_intros<-ggplot()  + theme_minimal()+
  geom_ribbon(data=africa_to_africa_table_summarize,aes(x=date4, y=mean,fill='Within\nAfrica', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=africa_to_africa_table_summarize,aes(x=date4, y=mean, color='Within\nAfrica'))+
  geom_ribbon(data=europe_to_africa_table_summarize,aes(x=date4, y=mean,fill='From\nEurope', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=europe_to_africa_table_summarize,aes(x=date4, y=mean, color='From\nEurope'))+
  
  geom_ribbon(data=europe_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='To Europe', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=europe_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='To Europe'),linetype='dashed')+
  
  geom_ribbon(data=Namerica_to_africa_table_summarize,aes(x=date4, y=mean,fill='From North\nAmerica', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=Namerica_to_africa_table_summarize,aes(x=date4, y=mean, color='From North\nAmerica'))+
  geom_ribbon(data=Namerica_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='To North\nAmerica', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=Namerica_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='To North\nAmerica'), linetype='dashed')+
  
  #geom_ribbon(data=asia_to_africa_table_summarize,aes(x=date4, y=mean,fill='From\nAsia', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  #geom_line(data=asia_to_africa_table_summarize,aes(x=date4, y=mean, color='From\nAsia'))+
  #geom_ribbon(data=asia_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='To Asia', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  #geom_line(data=asia_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='To Asia'), linetype='dashed')+
  
  #geom_ribbon(data=Samerica_to_africa_table_summarize,aes(x=date4, y=mean,fill='From South\nAmerica', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  #geom_line(data=Samerica_to_africa_table_summarize,aes(x=date4, y=mean, color='From South\nAmerica'))+
  
  #geom_ribbon(data=Samerica_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='to South America', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  #geom_line(data=Samerica_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='to South America'), linetype='dashed')+


#geom_ribbon(data=australia_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='to Australia', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
#geom_line(data=australia_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='to Australia'), linetype='dashed')+
scale_colour_manual(values=cols,name='')+
  scale_fill_manual(values=cols,name='')+
  #scale_colour_brewer(palette='Dark2', name='')+
  #scale_fill_brewer(palette='Dark2', name='')+
  theme(legend.position = 'top', legend.title = element_text(size=10),legend.text = element_text(size=10))+
  xlab('')+
  ylab('Number of\nViral Exchanges')+
  scale_y_continuous(trans = "log10", limits = c(1,200))+
  
  scale_x_date(date_labels = "%b\n%Y",date_breaks = "2 months", limits=as.Date(c("2021/10/15","2022/02/28")))

omicron_intros


df_africa<-africa_metadata
df_africa$date<-as.Date(df_africa$date)

df_africa$days<-as.Date(cut(df_africa$date,breaks = "day",start.on.monday = FALSE))
df_africa$date2<-as.Date(cut(df_africa$date,breaks = "2 weeks",start.on.monday = FALSE))
df_africa$date3<-as.Date(cut(df_africa$date,breaks = "1 month",start.on.monday = FALSE))
df_africa$date<-as.Date(cut(df_africa$date,breaks = "1 week",start.on.monday = FALSE))

omicron_prevalence<-ggplot(df_africa)+ theme_minimal()+
  geom_bar(color='black', size=0.1,position='fill',mapping = aes(x=date2,fill=Nextstrain_clade %like% '21K'))+
  scale_fill_manual(values=c('white','grey30'),name='Lineages', labels=c('Others','BA.1'))+
  theme(legend.position = 'top', legend.title = element_text(size=10),legend.text = element_text(size=10))+
  ylab('Genomic\nPrevalence')+
  xlab('')+
  scale_y_continuous(limits = c(0,1),breaks = c(0,0.5,1))+
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank())+
  scale_x_date(date_labels = "%b\n%Y",date_breaks = "2 months", limits=as.Date(c("2021/10/15","2022/02/28")))

omicron_prevalence

omicron_FigAB<-plot_grid(omicron_prevalence,omicron_intros,align='v',ncol=1, rel_heights = c(0.4,0.6))
omicron_FigAB


omicron_all_replicates<-omicron_all_replicates_africa_0008
africa_to_africa<-subset(subset(omicron_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='Africa')

world3 <- map_data("world")

world3<- world3 %>% 
  left_join(africa_to_africa, by = c("region" = "Destination"))

africa_to_africa$Origin_Continent_Region<-as.character(africa_to_africa$Origin_Continent_Region)

africa_to_africa<-africa_to_africa %>%
  dplyr::group_by(Origin)%>%
  dplyr::mutate(number=n())
#regional_cols<-c("Eastern Africa" = "#1b9e77", "Southern Africa" = "#d95f02", "Western Africa" = "#7570b3", "Northern Africa" = "#e7298a")

omicron_africa_map<-ggplot() +
  theme_void()+
  #coord_map("gilbert")+
  geom_map(data=world3,map=world3, aes(long, lat,map_id=region), color="grey40", fill='white',size=0.2)+
  
  geom_curve(data = africa_to_africa,
             aes(x = as.double(origin_long), 
                 y = as.double(origin_lat), 
                 xend = as.double(destination_long), 
                 yend = as.double(destination_lat), colour=Origin_Continent_Region),
             size=0.8)+
  geom_point(data = africa_to_africa,
             aes(x = as.double(origin_long), y = as.double(origin_lat), fill=Origin_Continent_Region,size=number),
             color='black', shape=21)+
  scale_color_manual(values=regional_cols, name='Regions of Origin')+
  scale_fill_manual(values=regional_cols, name='Regions of Origin')+
  theme(legend.position = 'none')+
  theme(legend.direction = 'horizontal')+
  
  #scale_color_brewer(palette='Dark2', name='Regions of Origin')+
  #scale_fill_brewer(palette='Dark2', name='Regions of Origin')+
  scale_x_continuous(limits = c(-20, 60))+
  scale_y_continuous(limits = c(-35, 38))


omicron_africa_map

omicron_all<-plot_grid(omicron_FigAB,omicron_africa_map, ncol=1, rel_heights=c(0.55,0.45))
omicron_all


## Omicron BA.2

#Africa-focused

replicate1<-read.table(file='ImportExport/BA2_Africa_focused_0.0008/boot1_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate1$replicate <- "1"
replicate2<-read.table(file='ImportExport/BA2_Africa_focused_0.0008/boot2_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate2$replicate <- "2"
replicate3<-read.table(file='ImportExport/BA2_Africa_focused_0.0008/boot3_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate3$replicate <- "3"
replicate4<-read.table(file='ImportExport/BA2_Africa_focused_0.0008/boot4_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate4$replicate <- "4"
replicate5<-read.table(file='ImportExport/BA2_Africa_focused_0.0008/boot5_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate5$replicate <- "5"
replicate6<-read.table(file='ImportExport/BA2_Africa_focused_0.0008/boot6_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate6$replicate <- "6"
replicate7<-read.table(file='ImportExport/BA2_Africa_focused_0.0008/boot7_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate7$replicate <- "7"
replicate8<-read.table(file='ImportExport/BA2_Africa_focused_0.0008/boot8_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate8$replicate <- "8"
replicate9<-read.table(file='ImportExport/BA2_Africa_focused_0.0008/boot9_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate9$replicate <- "9"
replicate10<-read.table(file='ImportExport/BA2_Africa_focused_0.0008/boot10_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate10$replicate <- "10"


BA2_all_replicates<-rbind(replicate1,replicate2,replicate3,replicate4,
                          replicate5,replicate6,replicate7,replicate8,
                          replicate9,replicate10)
BA2_all_replicates[BA2_all_replicates == "USA"] <- "United States"
BA2_all_replicates[BA2_all_replicates == "Republic of the Congo"] <- "Congo (Brazzaville)"
BA2_all_replicates[BA2_all_replicates == "Democratic Republic of the Congo"] <- "Congo (Kinshasa)"

BA2_all_replicates[BA2_all_replicates == "Coted Ivoire"] <- "Ivory Coast"

BA2_all_replicates<-subset(BA2_all_replicates,Origin!='Reunion')
BA2_all_replicates<-subset(BA2_all_replicates,Origin!='Mayotte')

BA2_all_replicates$date<-date_decimal(BA2_all_replicates$EventTime)

BA2_all_replicates$Origin_Continent<-lapply(BA2_all_replicates$Origin,country2continent)
BA2_all_replicates$Destination_Continent<-lapply(BA2_all_replicates$Destination,country2continent)

BA2_all_replicates$Origin_Continent_Region<-lapply(BA2_all_replicates$Origin,country2continent_region)
BA2_all_replicates$Destination_Continent_Region<-lapply(BA2_all_replicates$Destination,country2continent_region)

BA2_all_replicates$Variant <- "Omicron"

BA2_all_replicates$days<-as.Date(cut(BA2_all_replicates$date,breaks = "day",start.on.monday = FALSE))
BA2_all_replicates$date<-as.Date(cut(BA2_all_replicates$date,breaks = "week",start.on.monday = FALSE))
BA2_all_replicates$date2<-as.Date(cut(BA2_all_replicates$date,breaks = "2 week",start.on.monday = FALSE))
BA2_all_replicates$date4<-as.Date(cut(BA2_all_replicates$date,breaks = "1 month",start.on.monday = FALSE))


BA2_all_replicates$destination_lat<- lapply(BA2_all_replicates$Destination,country2lat)
BA2_all_replicates$destination_long<- lapply(BA2_all_replicates$Destination,country2long)

BA2_all_replicates$origin_lat<- lapply(BA2_all_replicates$Origin,country2lat)
BA2_all_replicates$origin_long<- lapply(BA2_all_replicates$Origin,country2long)

BA2_all_replicates_africa_0008<-BA2_all_replicates


#Global

replicate1<-read.table(file='ImportExport/BA2_0.0008/africa/africa_seed0987_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate1$replicate <- "1"
replicate2<-read.table(file='ImportExport/BA2_0.0008/africa/africa_seed1234_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate2$replicate <- "2"
replicate3<-read.table(file='ImportExport/BA2_0.0008/africa/africa_seed2345_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate3$replicate <- "3"
replicate4<-read.table(file='ImportExport/BA2_0.0008/africa/africa_seed3456_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate4$replicate <- "4"
replicate5<-read.table(file='ImportExport/BA2_0.0008/africa/africa_seed4567_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate5$replicate <- "5"
replicate6<-read.table(file='ImportExport/BA2_0.0008/africa/africa_seed5678_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate6$replicate <- "6"
replicate7<-read.table(file='ImportExport/BA2_0.0008/africa/africa_seed6789_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate7$replicate <- "7"
replicate8<-read.table(file='ImportExport/BA2_0.0008/africa/africa_seed7890_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate8$replicate <- "8"
replicate9<-read.table(file='ImportExport/BA2_0.0008/africa/africa_seed8901_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate9$replicate <- "9"
replicate10<-read.table(file='ImportExport/BA2_0.0008/africa/africa_seed9012_annottated_tree_events.csv', sep = '\t', header = TRUE)
replicate10$replicate <- "10"


BA2_all_replicates<-rbind(replicate1,replicate2,replicate3,replicate4,
                          replicate5,replicate6,replicate7,replicate8,
                          replicate9,replicate10)
BA2_all_replicates[BA2_all_replicates == "USA"] <- "United States"
BA2_all_replicates[BA2_all_replicates == "Republic of the Congo"] <- "Congo (Brazzaville)"
BA2_all_replicates[BA2_all_replicates == "Democratic Republic of the Congo"] <- "Congo (Kinshasa)"

BA2_all_replicates[BA2_all_replicates == "Coted Ivoire"] <- "Ivory Coast"

BA2_all_replicates<-subset(BA2_all_replicates,Origin!='Reunion')
BA2_all_replicates<-subset(BA2_all_replicates,Origin!='Mayotte')

BA2_all_replicates$date<-date_decimal(BA2_all_replicates$EventTime)

BA2_all_replicates$Origin_Continent<-lapply(BA2_all_replicates$Origin,country2continent)
BA2_all_replicates$Destination_Continent<-lapply(BA2_all_replicates$Destination,country2continent)

BA2_all_replicates$Origin_Continent_Region<-lapply(BA2_all_replicates$Origin,country2continent_region)
BA2_all_replicates$Destination_Continent_Region<-lapply(BA2_all_replicates$Destination,country2continent_region)

BA2_all_replicates$Variant <- "Omicron"

BA2_all_replicates$days<-as.Date(cut(BA2_all_replicates$date,breaks = "day",start.on.monday = FALSE))
BA2_all_replicates$date<-as.Date(cut(BA2_all_replicates$date,breaks = "week",start.on.monday = FALSE))
BA2_all_replicates$date2<-as.Date(cut(BA2_all_replicates$date,breaks = "2 week",start.on.monday = FALSE))
BA2_all_replicates$date4<-as.Date(cut(BA2_all_replicates$date,breaks = "1 month",start.on.monday = FALSE))


BA2_all_replicates$destination_lat<- lapply(BA2_all_replicates$Destination,country2lat)
BA2_all_replicates$destination_long<- lapply(BA2_all_replicates$Destination,country2long)

BA2_all_replicates$origin_lat<- lapply(BA2_all_replicates$Origin,country2lat)
BA2_all_replicates$origin_long<- lapply(BA2_all_replicates$Origin,country2long)

#BA2_all_replicates_global_0008<-BA2_all_replicates

BA2_all_replicates<-BA2_all_replicates_global_0008

unique(subset(BA2_all_replicates,Destination_Continent=='Africa')$Origin_Continent_Region)
unique(subset(BA2_all_replicates,Destination_Continent=='Africa')$Origin_Continent)
unique(subset(BA2_all_replicates,Origin_Continent=='Africa')$Destination_Continent)

#Africa-Africa
africa_to_africa<-subset(subset(BA2_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='Africa')
africa_to_africa_table <- africa_to_africa %>% count(date4, replicate)
africa_to_africa_table_summarize <- africa_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))
#imports_mozb_collapse_summarise$date_week <- as.POSIXct(imports_mozb_collapse_summarise$date_week)

#Europe-Africa
europe_to_africa<-subset(subset(BA2_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='Europe')
europe_to_africa_table <- europe_to_africa %>% count(date4, replicate)
europe_to_africa_table_summarize <- europe_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))

#exports
europe_to_africa_exports<-subset(subset(BA2_all_replicates,Origin_Continent=='Africa'),Destination_Continent=='Europe')
europe_to_africa_exports_table <- europe_to_africa_exports %>% count(date4, replicate)
europe_to_africa_exports_table_summarize <- europe_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


#NAmerica-Africa
Namerica_to_africa<-subset(subset(BA2_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='North America')
Namerica_to_africa_table <- Namerica_to_africa %>% count(date4, replicate)
Namerica_to_africa_table_summarize <- Namerica_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))

#exports
Namerica_to_africa_exports<-subset(subset(BA2_all_replicates,Origin_Continent=='Africa'),Destination_Continent=='North America')
Namerica_to_africa_exports_table <- Namerica_to_africa_exports %>% count(date4, replicate)
Namerica_to_africa_exports_table_summarize <- Namerica_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


#Asia-Africa
asia_to_africa<-subset(subset(BA2_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='Asia')
asia_to_africa_table <- asia_to_africa %>% count(date4, replicate)
asia_to_africa_table_summarize <- asia_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


#Asia-Africa
asia_to_africa_exports<-subset(subset(BA2_all_replicates,Destination_Continent=='Asia'),Origin_Continent=='Africa')
asia_to_africa_exports_table <- asia_to_africa_exports %>% count(date4, replicate)
asia_to_africa_exports_table_summarize <- asia_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


#SAmerica-Africa

Samerica_to_africa<-subset(subset(BA2_all_replicates,Origin_Continent=='South America'),Destination_Continent=='Africa')
Samerica_to_africa_table <- Samerica_to_africa %>% count(date4, replicate)
Samerica_to_africa_table_summarize <- Samerica_to_africa_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))

Samerica_to_africa_exports<-subset(subset(BA2_all_replicates,Origin_Continent=='Africa'),Destination_Continent=='South America')
Samerica_to_africa_exports_table <- Samerica_to_africa_exports %>% count(date4, replicate)
Samerica_to_africa_exports_table_summarize <- Samerica_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))



#Australia-Africa
australia_to_africa_exports<-subset(subset(BA2_all_replicates,Origin_Continent=='Africa'),Destination_Continent=='Australia')
australia_to_africa_exports_table <- australia_to_africa_exports %>% count(date4, replicate)
australia_to_africa_exports_table_summarize <- australia_to_africa_exports_table %>% group_by(date4)  %>% 
  summarise(mean = mean(n), sd = sd(n))


BA2_intros<-ggplot()  + theme_minimal()+
  #geom_ribbon(data=africa_to_africa_table_summarize,aes(x=date4, y=mean,fill='Within\nAfrica', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  #geom_line(data=africa_to_africa_table_summarize,aes(x=date4, y=mean, color='Within\nAfrica'))+
  geom_ribbon(data=europe_to_africa_table_summarize,aes(x=date4, y=mean,fill='From\nEurope', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=europe_to_africa_table_summarize,aes(x=date4, y=mean, color='From\nEurope'))+
  
  geom_ribbon(data=europe_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='To Europe', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=europe_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='To Europe'),linetype='dashed')+
  
  #geom_ribbon(data=Namerica_to_africa_table_summarize,aes(x=date4, y=mean,fill='From North\nAmerica', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  #geom_line(data=Namerica_to_africa_table_summarize,aes(x=date4, y=mean, color='From North\nAmerica'))+
  #geom_ribbon(data=Namerica_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='To North\nAmerica', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  #geom_line(data=Namerica_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='To North\nAmerica'), linetype='dashed')+
  
  geom_ribbon(data=asia_to_africa_table_summarize,aes(x=date4, y=mean,fill='From\nAsia', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=asia_to_africa_table_summarize,aes(x=date4, y=mean, color='From\nAsia'))+
  geom_ribbon(data=asia_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='To Asia', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  geom_line(data=asia_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='To Asia'), linetype='dashed')+
  
  #geom_ribbon(data=Samerica_to_africa_table_summarize,aes(x=date4, y=mean,fill='From South\nAmerica', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  #geom_line(data=Samerica_to_africa_table_summarize,aes(x=date4, y=mean, color='From South\nAmerica'))+
  
  #geom_ribbon(data=Samerica_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='to South America', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  #geom_line(data=Samerica_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='to South America'), linetype='dashed')+
  
  
  #geom_ribbon(data=australia_to_africa_exports_table_summarize,aes(x=date4, y=mean,fill='to Australia', ymin=mean-sd,ymax=mean+sd), alpha=0.2)+
  #geom_line(data=australia_to_africa_exports_table_summarize,aes(x=date4, y=mean, color='to Australia'), linetype='dashed')+
  scale_colour_manual(values=cols,name='')+
  scale_fill_manual(values=cols,name='')+
  #scale_y_continuous(trans = "log10")+
  
  #scale_colour_brewer(palette='Dark2', name='')+
  #scale_fill_brewer(palette='Dark2', name='')+
  theme(legend.position = 'top', legend.title = element_text(size=10),legend.text = element_text(size=10))+
  guides(colour = guide_legend(nrow = 1),fill = guide_legend(nrow = 1))+
  xlab('')+
  ylab('Number of\nViral Exchanges')+
  scale_y_continuous(trans = "log10", limits = c(0.3,200))+
  
  scale_x_date(date_labels = "%b\n%Y",date_breaks = "2 months", limits=as.Date(c("2021/11/01","2022/03/15")))

BA2_intros


df_africa<-africa_metadata
df_africa$date<-as.Date(df_africa$date)

df_africa$days<-as.Date(cut(df_africa$date,breaks = "day",start.on.monday = FALSE))
df_africa$date2<-as.Date(cut(df_africa$date,breaks = "2 weeks",start.on.monday = FALSE))
df_africa$date3<-as.Date(cut(df_africa$date,breaks = "1 month",start.on.monday = FALSE))
df_africa$date<-as.Date(cut(df_africa$date,breaks = "1 week",start.on.monday = FALSE))

BA2_prevalence<-ggplot(df_africa)+ theme_minimal()+
  geom_bar(color='black', size=0.1,position='fill',mapping = aes(x=date2,fill=Nextstrain_clade %like% '21L'))+
  scale_fill_manual(values=c('white','grey30'),name='Lineages', labels=c('Others','BA.2'))+
  theme(legend.position = 'top', legend.title = element_text(size=10),legend.text = element_text(size=10))+
  ylab('Genomic\nPrevalence')+
  xlab('')+
  scale_y_continuous(limits = c(0,1),breaks = c(0,0.5,1))+
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank())+
  scale_x_date(date_labels = "%b\n%Y",date_breaks = "2 months", limits=as.Date(c("2021/11/01","2022/03/15")))

BA2_prevalence

BA2_FigAB<-plot_grid(BA2_prevalence,BA2_intros,align='v',ncol=1, rel_heights = c(0.4,0.6))
BA2_FigAB


BA2_all_replicates<-BA2_all_replicates_africa_0008
africa_to_africa<-subset(subset(BA2_all_replicates,Destination_Continent=='Africa'),Origin_Continent=='Africa')

world3 <- map_data("world")

world3<- world3 %>% 
  left_join(africa_to_africa, by = c("region" = "Destination"))

africa_to_africa$Origin_Continent_Region<-as.character(africa_to_africa$Origin_Continent_Region)

africa_to_africa<-africa_to_africa %>%
  dplyr::group_by(Origin)%>%
  dplyr::mutate(number=n())

BA2_africa_map<-ggplot() +
  theme_void()+
  #coord_map("gilbert")+
  geom_map(data=world3,map=world3, aes(long, lat,map_id=region), color="grey40", fill='white',size=0.2)+
  
  geom_curve(data = africa_to_africa,
             aes(x = as.double(origin_long), 
                 y = as.double(origin_lat), 
                 xend = as.double(destination_long), 
                 yend = as.double(destination_lat), colour=Origin_Continent_Region),
             size=0.8)+
  geom_point(data = africa_to_africa,
             aes(x = as.double(origin_long), y = as.double(origin_lat), fill=Origin_Continent_Region,size=number),
             color='black', shape=21)+
  scale_color_manual(values=regional_cols, name='Regions of Origin')+
  scale_fill_manual(values=regional_cols, name='Regions of Origin')+
  theme(legend.position = 'none')+
  theme(legend.direction = 'horizontal')+
  
  #scale_color_brewer(palette='Dark2', name='Regions of Origin')+
  #scale_fill_brewer(palette='Dark2', name='Regions of Origin')+
  scale_x_continuous(limits = c(-20, 60))+
  scale_y_continuous(limits = c(-35, 38))


BA2_africa_map

BA2_all<-plot_grid(BA2_FigAB,BA2_africa_map, ncol=1, rel_heights=c(0.55,0.45))
BA2_all


### Combine Import Export Figures

all_import_export<-plot_grid(alpha_all,beta_all,delta_all,omicron_all,BA2_all, ncol=5)
all_import_export

ggsave("Fig4_colours_updated.pdf", all_import_export, device = "pdf", width = 55, height = 28, units = "cm", limitsize = FALSE) 

