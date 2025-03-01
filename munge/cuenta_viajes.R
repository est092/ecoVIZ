library(dplyr)
library(ggplot2)
library(lubridate)
library(tidyr)
library(zoo)
setwd("/home/esteban/ecobici")
estaciones=read.csv("data/estaciones.csv") %>%
  mutate(coordenadas=paste0(`location.lat`,",",`location.lon`), 
         longitud=location.lon,
         latitud=location.lat,
         estacion=id, id=row_number()) 


# load("data/base_polanco.RData")
estado=readRDS("cache/fotos_inventario/2019-06-12-5.RDS")
estado=estado$stationsStatus.availability  %>% mutate(id=estado$stationsStatus.id) %>% select(id, inicial=slots)
load("data/base_completa.RData")
dias_habiles=c("viernes","lunes", "martes","miércoles","jueves")
dat_full=read.csv("data/bases/2019-06.csv",stringsAsFactors = FALSE)


base=dat_full %>%
  select(-c(Genero_Usuario,Edad_Usuario,Bici)) %>%
  mutate_at(c("Fecha_Retiro","Fecha_Arribo"),function(x)as.Date(x,"%d/%m/%Y")) %>%
  mutate(Hora_Retiro=paste0(Fecha_Retiro," ",Hora_Retiro) %>% as.POSIXct(),
         Hora_Arribo=paste0(Fecha_Arribo," ",Hora_Arribo)%>% as.POSIXct()) %>%
  filter(Hora_Arribo<as.Date("2019-06-13") & Hora_Retiro>=as.Date("2019-06-12")) %>%
  # filter(Ciclo_Estacion_Retiro %in% seleccionadas | Ciclo_Estacion_Arribo %in% seleccionadas) %>%
  mutate(dia_semana_retiro=weekdays(Hora_Retiro),
         dia_semana_arribo=weekdays(Hora_Arribo),
         horas_retiro=hour(Hora_Retiro),
         horas_arribo=hour(Hora_Arribo) ,
         periodo_retiro=floor_date(Hora_Retiro, unit="15 minutes"),
         periodo_arribo=floor_date(Hora_Arribo, unit="15 minutes")) 
load("cache/capacity.RData")  


# pad_estacion=expand.grid(hora=seq(from=as.POSIXct("2019-06-12"),to=as.POSIXct("2019-06-13"),by="15 mins"),estacion=unique(base$Ciclo_Estacion_Retiro))
pad_estacion=expand.grid(hora=seq(from=as.POSIXct("2019-06-12"),to=as.POSIXct("2019-06-13"),by="15 mins"),estacion=unique(base$Ciclo_Estacion_Retiro))



temp=base %>%
  group_by(estacion=Ciclo_Estacion_Retiro,hora=periodo_retiro) %>%
  summarise(n_retiro=n()) %>%
  full_join(pad_estacion,by=c("estacion","hora")) %>%
  bind_rows({
    base %>%
      group_by(estacion=Ciclo_Estacion_Arribo,hora=periodo_arribo) %>%
      summarise(n_arribo=n())   }) %>%
  group_by(estacion,hora) %>%
  summarise(n_retiro=sum(n_retiro, na.rm = TRUE), n_arribo=sum(n_arribo, na.rm = TRUE)) %>%
  ungroup() %>%
  arrange(estacion, hora) %>%
  group_by(estacion) %>%
  # padr::pad(interval = "1 hour",start_val = as.POSIXct("2019-06-01 00:00:00"),end_val = as.POSIXct("2019-07-01 00:00:00")) %>%
  # padr::fill_by_value(n_retiro,n_arribo,fill=0) %>%
  mutate(retiros_60_min=rollsum(n_retiro,k=4,fill = NA,align = "right"), arribos_60_min=rollsum(n_arribo,k=4,fill = NA,align = "right")) %>%
  ungroup() %>%
  left_join(estaciones %>% select(id, districtName), by=c("estacion"="id")) %>%
  left_join(capacity,by=c("estacion"="id")) %>%
  left_join(estado %>% select(id,inicial) ,by=c("estacion"="id"))%>%
  arrange(hora) %>% 
  group_by(estacion) %>% mutate(cambio=n_arribo-n_retiro,
                                                               estado=inicial+ cumsum(cambio ) ) 
# %>% filter(estacion==451)
write.csv(temp,file="/home/esteban/ecobici-visualizacion/data/12-06-19.csv",row.names = FALSE)

pad_estacion_2=expand.grid(hora=seq(from=as.POSIXct("2019-06-12"),to=as.POSIXct("2019-06-13"),by="15 mins"),estacion_retiro=unique(base$Ciclo_Estacion_Retiro),
                           estacion_arribo=unique(base$Ciclo_Estacion_Arribo))

temp=base %>%
  group_by(estacion_retiro=Ciclo_Estacion_Retiro,estacion_arribo=Ciclo_Estacion_Arribo,hora=periodo_retiro) %>%
  summarise(n=n()) %>%
  full_join(pad_estacion_2,by=c("estacion_retiro","estacion_arribo","hora")) %>%
  bind_rows({
    base %>%
      group_by(estacion_retiro=Ciclo_Estacion_Arribo,estacion_arribo=Ciclo_Estacion_Retiro,hora=periodo_retiro) %>%
      summarise(n=n())
    }) %>%
  group_by(estacion_retiro,estacion_arribo,hora) %>%
  summarise(n=sum(n, na.rm = TRUE)) %>%
  ungroup() %>%
  arrange(estacion_retiro,estacion_arribo,hora) %>%
  group_by(estacion_retiro,estacion_arribo) %>%
  # padr::pad(interval = "1 hour",start_val = as.POSIXct("2019-06-01 00:00:00"),end_val = as.POSIXct("2019-07-01 00:00:00")) %>%
  # padr::fill_by_value(n_retiro,n_arribo,fill=0) %>%
  mutate(viajes_60_min=rollsum(n,k=4,fill = NA,align = "right")) %>%
  ungroup()



## C
# 
# temp=base %>%
#   group_by(estacion_retiro=Ciclo_Estacion_Retiro,estacion_arribo=Ciclo_Estacion_Arribo,hora=periodo_retiro) %>%
#   summarise(n=n()) %>%
#   # full_join(pad_estacion_2,by=c("estacion_retiro","estacion_arribo","hora")) %>%
#   bind_rows({
#     base %>%
#       group_by(estacion_retiro=Ciclo_Estacion_Arribo,estacion_arribo=Ciclo_Estacion_Retiro,hora=periodo_retiro) %>%
#       summarise(n=n())
#   })



pad_estacion_3=expand.grid(hora=seq(from=as.POSIXct("2019-06-12"),to=as.POSIXct("2019-06-13"),by="15 mins"),estacion=unique(paste0(temp$estacion_retiro,"--",temp$estacion_arribo))) %>%
  separate(estacion,c("estacion_retiro","estacion_arribo"),sep="--",remove=TRUE) %>%mutate_at(c(c("estacion_retiro","estacion_arribo")), function(x)as.numeric(x))
serie=temp %>%
  full_join(pad_estacion_3,by=c("estacion_retiro","estacion_arribo","hora"))%>%
  group_by(estacion_retiro,estacion_arribo,hora) %>%
  summarise(n=sum(n, na.rm = TRUE)) %>%
  ungroup() %>%
  arrange(estacion_retiro,estacion_arribo,hora) %>%
  group_by(estacion_retiro,estacion_arribo) %>%
  # padr::pad(interval = "1 hour",start_val = as.POSIXct("2019-06-01 00:00:00"),end_val = as.POSIXct("2019-07-01 00:00:00")) %>%
  # padr::fill_by_value(n_retiro,n_arribo,fill=0) %>%
  mutate(viajes_60_min=rollsum(n,k=4,fill = NA,align = "right")) %>%
  ungroup()


write.csv(serie,file="/home/esteban/ecobici-visualizacion/data/12-06-19-aristas.csv",row.names = FALSE)
