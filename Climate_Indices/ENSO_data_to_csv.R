#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Data Soruce
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

#°°°°°° DataFrames: Monthly and seasonal climate indices
#°°°°°° (DATA: AAO, NAO, SST, SOI, OLR, RONI, MEI.v2, AMO, SCAND, EA, WEMO)

#°°°°°° Source: https://psl.noaa.gov/data/timeseries/month/
#°°°°°°         https://centroandaluzengloba.org/en/wemo-index-monitoring/

# Libraries ·····································································

library(ggplot2)
library(dplyr)
library(tidyr)

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Files ·····································································
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

path = "~/Escritorio/UCM_Madrid/Climate_Indices/"
path_csv = "~/Escritorio/UCM_Madrid/Climate_Indices/CSV/"

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# AAO Data (monthly dataset)

aao_NOAA_1979_2026 <- read.table(paste(path,'aao_NOAA_1979_2026.ascii', sep = ""), header = FALSE, sep = "")

# To match fire data
colnames(aao_NOAA_1979_2026)[1:3] <- c("year", "month", "aao")

# Save monthly stats
write.csv(aao_NOAA_1979_2026, paste0(path_csv,"aao_NOAA_1979_2026.csv"), row.names = FALSE)

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# NAO Data (monthly dataset)

nao_NOAA_1950_2026 <- read.table(paste(path,'nao.NOAA_1950_2026.ascii', sep = ""), header = FALSE, sep = "")

# To match fire data
colnames(nao_NOAA_1950_2026)[1:3] <- c("year", "month", "nao")

# Save monthly stats
write.csv(nao_NOAA_1950_2026, paste0(path_csv,"nao_NOAA_1950_2026.csv"), row.names = FALSE)

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# SST Data (monthly dataset)

sst_NOAA_1982_2026 <- read.table(paste(path,'sst_NOAA_1982_2026.txt', sep = ""), header = TRUE, sep = "")

# To match fire data
colnames(sst_NOAA_1982_2026)[1:2] <- c("year", "month")

# Save monthly stats
write.csv(sst_NOAA_1982_2026, paste0(path_csv,"sst_NOAA_1982_2026.csv"), row.names = FALSE)

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# SOI Data (monthly dataset)

# SOI standard Data 
soi_st_NOAA_1951_2026 <- read.table(paste(path, "soi_st_NOAA_1951_2026.txt", sep = ""), header = TRUE)

soi_long <- soi_st_NOAA_1951_2026 %>%
  pivot_longer(-YEAR, names_to = "month", values_to = "soi_st") %>%
  mutate(month = match(month, c("JAN","FEB","MAR","APR","MAY","JUN",
                                "JUL","AUG","SEP","OCT","NOV","DEC"))) %>%
  rename(year = YEAR)

# SOI anomaly Data 

soi_anomaly_NOAA_1951_2026 <- read.table(paste(path, "soi_anomaly_NOAA_1951_2026.txt", sep = ""), header = TRUE)

soi_long_2 <- soi_anomaly_NOAA_1951_2026 %>%
  pivot_longer(-YEAR, names_to = "month", values_to = "soi_ano") %>%
  mutate(month = match(month, c("JAN","FEB","MAR","APR","MAY","JUN",
                                "JUL","AUG","SEP","OCT","NOV","DEC"))) %>%
  rename(year = YEAR)

# Join all SOI data together (standard Data and anomaly data) 

soi_NOAA_1951_2026 <- soi_long %>%
  left_join(soi_long_2, by = c("year", "month"))

# Save monthly stats
write.csv(soi_NOAA_1951_2026,  paste0(path_csv,"soi_NOAA_1951_2026.csv"), row.names = FALSE)

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# OLR Data (monthly dataset)

# ORL standard Data 

olr_st_NOAA_1974_2026 <- read.table(
  paste(path, "olr_st_NOAA_1974_2026.txt", sep = ""),
  header = TRUE,
  fill = TRUE,
  na.strings = "-999.9"
)

orl_long <- olr_st_NOAA_1974_2026 %>%
  pivot_longer(-YEAR, names_to = "month", values_to = "olr_st") %>%
  mutate(month = match(month, c("JAN","FEB","MAR","APR","MAY","JUN",
                                "JUL","AUG","SEP","OCT","NOV","DEC"))) %>%
  rename(year = YEAR)


# ORL anomaly Data 

olr_anomaly_NOAA_1974_2026 <- read.table(
  paste(path, "olr_anomaly_NOAA_1974_2026.txt", sep = ""),
  header = TRUE,
  fill = TRUE,
  na.strings = "-999.9"
)

olr_long_2 <- olr_anomaly_NOAA_1974_2026 %>%
  pivot_longer(-YEAR, names_to = "month", values_to = "olr_ano") %>%
  mutate(month = match(month, c("JAN","FEB","MAR","APR","MAY","JUN",
                                "JUL","AUG","SEP","OCT","NOV","DEC"))) %>%
  rename(year = YEAR)


# Join all olr data together (standard Data and anomaly data) 

olr_NOAA_1974_2026 <- orl_long %>%
  left_join(olr_long_2, by = c("year", "month"))


# Save monthly stats
write.csv(olr_NOAA_1974_2026, paste0(path_csv,"olr_NOAA_1974_2026.csv"), row.names = FALSE)

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# RONI Data (seasonal dataset)

RONI_NOAA_1950_2026 <- read.table(paste(path, "RONI_NOAA_1950_2026.txt", sep = ""), header = TRUE)

# To match fire data
colnames(RONI_NOAA_1950_2026)[1:3] <- c("season", "year", "roni")

# Save monthly stats
write.csv(RONI_NOAA_1950_2026, paste0(path_csv,"RONI_NOAA_1950_2026.csv"), row.names = FALSE)


#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Multivariate ENSO Index Version 2 (MEI.v2) (data is organized in two months)

MEI_NOAA_1950_2026 <- read.table(paste(path, "meiv2_NOAA_1979_2026.txt", sep = ""), header = TRUE)

# To match fire data
colnames(RONI_NOAA_1950_2026)[1:3] <- c("season", "year", "mei")


mei_long <- MEI_NOAA_1950_2026 %>%
  pivot_longer(-YEAR, names_to = "months", values_to = "mei") %>%
  rename(year = YEAR)

# Save monthly stats
write.csv(mei_long, paste0(path_csv,"MEI_NOAA_1950_2026.csv"), row.names = FALSE)

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# AMO Data (monthly dataset)

# AMO standard Data 

amo_NOAA_1856_2022 <- read.table(
  paste(path, "amo_NOAA_1856_2022.txt", sep = ""),
  header = TRUE,
  fill = TRUE,
  na.strings = "-999.9"
)

amo_long <- amo_NOAA_1856_2022 %>%
  pivot_longer(-YEAR, names_to = "month", values_to = "amo") %>%
  mutate(month = match(month, c("JAN","FEB","MAR","APR","MAY","JUN",
                                "JUL","AUG","SEP","OCT","NOV","DEC"))) %>%
  rename(year = YEAR)

# Save monthly stats
write.csv(amo_long, paste0(path_csv,"amo_NOAA_1856_2022.csv"), row.names = FALSE)


#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# scand Data (monthly dataset)

# scand standard Data 

scand_NOAA_1850_2026 <- read.table(
  paste(path, "scand_NOAA_1950_2026.txt", sep = ""),
  header = TRUE,
  fill = TRUE,
  na.strings = "-999.9"
)

scand_long <- scand_NOAA_1850_2026 %>%
  pivot_longer(-YEAR, names_to = "month", values_to = "scand") %>%
  mutate(month = match(month, c("JAN","FEB","MAR","APR","MAY","JUN",
                                "JUL","AUG","SEP","OCT","NOV","DEC"))) %>%
  rename(year = YEAR)

# Save monthly stats
write.csv(scand_long, paste0(path_csv,"scand_NOAA_1850_2026.csv"), row.names = FALSE)

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# EA Data (monthly dataset)

EA_NOAA_1950_2026 <- read.table(paste(path,'ea_NOAA_1950_2026.txt', sep = ""), header = FALSE, sep = "")

# To match fire data
colnames(EA_NOAA_1950_2026)[1:3] <- c("year", "month", "ea")

# Save monthly stats
write.csv(EA_NOAA_1950_2026, paste0(path_csv,"ea_NOAA_1950_2026.csv"), row.names = FALSE)

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# WeMOi Data (monthly dataset)

# Read file, skip metadata lines starting with "#"
wemoi_lines <- readLines(paste0(path, "wemoi_1821_2026.csv"), encoding = "UTF-8")
wemoi_lines <- wemoi_lines[!grepl("^#", wemoi_lines) & nzchar(trimws(wemoi_lines))]

# Detect separator (tab or comma) from the header line
sep_wemoi <- ifelse(grepl("\t", wemoi_lines[1]), "\t", ",")

wemoi_1821_2026 <- read.table(text = wemoi_lines, header = TRUE, sep = sep_wemoi,
                              strip.white = TRUE, stringsAsFactors = FALSE,
                              fill = TRUE)

# Clean column names (removes BOM / spaces / uppercase)
colnames(wemoi_1821_2026) <- tolower(trimws(gsub("^\ufeff|^X\\.\\.\\.", "", colnames(wemoi_1821_2026))))

# Create year and month from date, then drop date
wemoi_1821_2026 <- wemoi_1821_2026 %>%
  mutate(date  = as.Date(date),
         year  = as.integer(format(date, "%Y")),
         month = as.integer(format(date, "%m"))) %>%
  select(year, month, wemoi, source, reliability)

# Save monthly stats
write.csv(wemoi_1821_2026, paste0(path_csv,"wemoi_1821_2026.csv"), row.names = FALSE)

# check wemoi_1821_2026

wemoi_1821_2026 %>%
  count(source, reliability)
