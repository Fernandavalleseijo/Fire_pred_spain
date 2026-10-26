#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

#°°°°°° Plots: Monthly and seasonal ENSO Data (DATA: amo, sst, soi, olr, RONI, MEI - Source: NOAA)

#°°°°°° Reads the CSV files created by the data-preparation script

# Libraries ·····································································

library(ggplot2)
library(dplyr)
library(tidyr)

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Paths ·····································································
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

path_csv  = ""
plot_path = ""

# Create the plots folder if it does not exist
dir.create(plot_path, showWarnings = FALSE, recursive = TRUE)

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Load CSV files ·····································································
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

sst_NOAA_1982_2026  <- read.csv(paste0(path_csv, "sst_NOAA_1982_2026.csv"))
nao_NOAA_1950_2026  <- read.csv(paste0(path_csv, "nao_NOAA_1950_2026.csv"))
aao_NOAA_1979_2026  <- read.csv(paste0(path_csv, "aao_NOAA_1979_2026.csv"))
soi_NOAA_1951_2026  <- read.csv(paste0(path_csv, "soi_NOAA_1951_2026.csv"))
olr_NOAA_1974_2026  <- read.csv(paste0(path_csv, "olr_NOAA_1974_2026.csv"))
RONI_NOAA_1950_2026 <- read.csv(paste0(path_csv, "RONI_NOAA_1950_2026.csv"))
amo_NOAA_1856_2022  <- read.csv(paste0(path_csv, "amo_NOAA_1856_2022.csv"))

# MEI csv is saved in long format (year, months, mei); -999 = missing months
MEI_NOAA_1979_2026  <- read.csv(paste0(path_csv, "MEI_NOAA_1950_2026.csv")) %>%
  rename(month = months) %>%
  filter(mei > -999)

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# PLOTS ·····································································
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

#-------------------------------------------------------------------------------
#  SST Data 

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#  Plot one index

# Create a date column (year + month)
sst_NOAA_1982_2026$date <- as.Date(
  paste(sst_NOAA_1982_2026$year, sst_NOAA_1982_2026$month, "01", sep = "-")
)

# Plot one index  (e.x NINO3.4)
SST_index_plot <- ggplot(sst_NOAA_1982_2026, aes(x = date, y = NINO4)) +
  geom_line(color = "blue", linewidth = 1) +
  scale_x_date(
    limits = range(sst_NOAA_1982_2026$date, na.rm = TRUE),
    date_breaks = "5 years",
    date_labels = "%Y",
    expand = c(0, 0)) +  # fixes 2000 and 2026
  labs(title = "NINO4 SST Index",
       x = "Year",
       y = "Temperature (°C)") +
  theme_bw() +
  theme(axis.text.y = element_text(size = 20),
        axis.title.y = element_text(size = 20, margin = margin(r = 15)),
        axis.text.x = element_text(size = 30, angle = 45, margin = margin(t = 20)),
        axis.title.x = element_text(size = 20, margin = margin(t = 15)),
        title = element_text(size = 20, family = "serif"),
        text  = element_text(family = "serif"))

SST_index_plot

ggsave(SST_index_plot, filename = file.path(plot_path, "SST_NINO4_1982-2026_by_month.png"), width = 1250, height = 650, units = "px", dpi=96)

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Compare all index

sst_long <- pivot_longer(
  sst_NOAA_1982_2026,
  cols = c(NINO3, NINO4, NINO3.4),
  names_to = "Index",
  values_to = "Temperature"
)

SST_all_index_plot <- ggplot(sst_long, aes(x = date, y = Temperature, color = Index)) +
  geom_line(linewidth = 1) +
  scale_x_date(
    limits = range(sst_long$date, na.rm = TRUE),
    date_breaks = "5 years",
    date_labels = "%Y",
    expand = c(0, 0)) +  # fixes 2000 and 2026
  labs(title = "SST Indices Comparison",
       x = "Year",
       y = "Temperature (°C)") +
  theme_bw() +
  theme(axis.text.y = element_text(size = 20),
        axis.title.y = element_text(size = 20, margin = margin(r = 15)),
        axis.text.x = element_text(size = 30, angle = 45, margin = margin(t = 20)),
        axis.title.x = element_text(size = 20, margin = margin(t = 15)),
        title = element_text(size = 20, family = "serif"),
        text  = element_text(family = "serif"))

SST_all_index_plot

ggsave(SST_all_index_plot, filename = file.path(plot_path, "SST_all_index_1982-2026_by_month.png"), width = 1250, height = 650, units = "px", dpi=96)

#-------------------------------------------------------------------------------
# NAO Data (monthly dataset)

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# nao plot

# Create date column
nao_NOAA_1950_2026$date <- as.Date(
  paste(nao_NOAA_1950_2026$year,
        nao_NOAA_1950_2026$month, "01", sep = "-")
)

nao_plot <- ggplot(nao_NOAA_1950_2026, aes(x = date, y = nao)) +
  geom_line(color = "darkgreen", linewidth = 1) +
  scale_x_date(
    limits = range(nao_NOAA_1950_2026$date, na.rm = TRUE),
    date_breaks = "5 years",
    date_labels = "%Y",
    expand = c(0, 0)) +  # fixes 2000 and 2026
  labs(title = "North Atlantic Oscillation (NAO)",
       x = "Year",
       y = "NAO") +
  theme_bw() +
  theme(axis.text.y = element_text(size = 20),
        axis.title.y = element_text(size = 20, margin = margin(r = 15)),
        axis.text.x = element_text(size = 30, angle = 45, margin = margin(t = 20)),
        axis.title.x = element_text(size = 20, margin = margin(t = 15)),
        title = element_text(size = 20, family = "serif"),
        text  = element_text(family = "serif"))

nao_plot

ggsave(nao_plot, filename = file.path(plot_path, "nao_1950-2026_by_month.png"), width = 1250, height = 650, units = "px", dpi=96)

#-------------------------------------------------------------------------------
# AAO Data (monthly dataset)

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# aao plot

# Create date column
aao_NOAA_1979_2026$date <- as.Date(
  paste(aao_NOAA_1979_2026$year,
        aao_NOAA_1979_2026$month, "01", sep = "-")
)

aao_plot <- ggplot(aao_NOAA_1979_2026, aes(x = date, y = aao)) +
  geom_line(color = "darkgreen", linewidth = 1) +
  scale_x_date(
    limits = range(aao_NOAA_1979_2026$date, na.rm = TRUE),
    date_breaks = "5 years",
    date_labels = "%Y",
    expand = c(0, 0)) +  # fixes 2000 and 2026
  labs(title = "Antarctic Oscillation (AAO)",
       x = "Year",
       y = "AAO") +
  theme_bw() +
  theme(axis.text.y = element_text(size = 20),
        axis.title.y = element_text(size = 20, margin = margin(r = 15)),
        axis.text.x = element_text(size = 30, angle = 45, margin = margin(t = 20)),
        axis.title.x = element_text(size = 20, margin = margin(t = 15)),
        title = element_text(size = 20, family = "serif"),
        text  = element_text(family = "serif"))

aao_plot

ggsave(aao_plot, filename = file.path(plot_path, "aao_1979-2026_by_month.png"), width = 1250, height = 650, units = "px", dpi=96)

#-------------------------------------------------------------------------------
# SOI Data (monthly dataset)

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# SOI plot

# Create date column
soi_NOAA_1951_2026$date <- as.Date(
  paste(soi_NOAA_1951_2026$year,
        soi_NOAA_1951_2026$month, "01", sep = "-")
)

soi_plot <- ggplot(soi_NOAA_1951_2026, aes(x = date, y = soi_st)) +
  geom_line(color = "darkgreen", linewidth = 1) +
  scale_x_date(
    limits = range(soi_NOAA_1951_2026$date, na.rm = TRUE),
    date_breaks = "5 years",
    date_labels = "%Y",
    expand = c(0, 0)) +  # fixes 2000 and 2026
  labs(title = "Southern Oscillation Index (SOI)",
       x = "Year",
       y = "SOI") +
  theme_bw() +
  theme(axis.text.y = element_text(size = 20),
        axis.title.y = element_text(size = 20, margin = margin(r = 15)),
        axis.text.x = element_text(size = 30, angle = 45, margin = margin(t = 20)),
        axis.title.x = element_text(size = 20, margin = margin(t = 15)),
        title = element_text(size = 20, family = "serif"),
        text  = element_text(family = "serif"))


ggsave(soi_plot, filename = file.path(plot_path, "SOI_1951-2026_by_month.png"), width = 1250, height = 650, units = "px", dpi=96)

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# SOI anomaly plot

soi_ano_plot  <-  ggplot(soi_NOAA_1951_2026, aes(x = date, y = soi_ano)) +
  geom_line() +
  geom_hline(yintercept = 0, linetype = "dashed") +
  geom_hline(yintercept = c(-1, 1), linetype = "dotted", color = "gray") + # below -1 → El Niño // above +1 → La Niña
  scale_x_date(
    limits = range(soi_NOAA_1951_2026$date, na.rm = TRUE),
    date_breaks = "5 years",
    date_labels = "%Y",
    expand = c(0, 0)) +  # fixes 2000 and 2026
  labs(title = "SOI with ENSO Thresholds",
       x = "Year",
       y = "SOI Anomaly") +
  annotate("text",
           x = min(soi_NOAA_1951_2026$date, na.rm = TRUE),
           y = 2,
           label = "La Niña",
           hjust = 0,
           color = "blue",
           size = 5) +
  
  annotate("text",
           x = min(soi_NOAA_1951_2026$date, na.rm = TRUE),
           y = -2,
           label = "El Niño",
           hjust = 0,
           color = "red",
           size = 5) +
  theme_bw() +
  theme(axis.text.y = element_text(size = 20),
        axis.title.y = element_text(size = 20, margin = margin(r = 15)),
        axis.text.x = element_text(size = 30, angle = 45, margin = margin(t = 20)),
        axis.title.x = element_text(size = 20, margin = margin(t = 15)),
        title = element_text(size = 20, family = "serif"),
        text  = element_text(family = "serif"))

ggsave(soi_ano_plot, filename = file.path(plot_path, "SOI_ano_1951-2026_by_month.png"), width = 1250, height = 650, units = "px", dpi=96)



#-------------------------------------------------------------------------------
# ORL Data (monthly dataset)

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# ORL plot

# Create date column
olr_NOAA_1974_2026$date <- as.Date(
  paste(olr_NOAA_1974_2026$year,
        olr_NOAA_1974_2026$month, "01", sep = "-")
)

OLR_plot <- ggplot(olr_NOAA_1974_2026, aes(x = date, y = olr_st)) +
  geom_line(color = "darkgreen", linewidth = 1) +
  scale_x_date(
    limits = range(olr_NOAA_1974_2026$date, na.rm = TRUE),
    date_breaks = "5 years",
    date_labels = "%Y",
    expand = c(0, 0)) +  # fixes 2000 and 2026
  labs(title = "Outgoing Longwave Radiation (OLR)",
       x = "Year",
       y = "OLR") +
  theme_bw() +
  theme(axis.text.y = element_text(size = 20),
        axis.title.y = element_text(size = 20, margin = margin(r = 15)),
        axis.text.x = element_text(size = 30, angle = 45, margin = margin(t = 20)),
        axis.title.x = element_text(size = 20, margin = margin(t = 15)),
        title = element_text(size = 20, family = "serif"),
        text  = element_text(family = "serif"))


ggsave(OLR_plot, filename = file.path(plot_path, "OLR_1974-2026_by_month.png"), width = 1250, height = 650, units = "px", dpi=96)

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# ORL anomaly plot

# Negative OLR anomaly → more clouds → Enhenced convection →️ (El Niño-like in central Pacific)
# Positive OLR anomaly → less clouds → suppressed convection

OLR_ano_plot <- ggplot(olr_NOAA_1974_2026, aes(x = date, y = olr_ano)) +
  geom_line(color = "darkorange") +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_date(
    limits = range(olr_NOAA_1974_2026$date, na.rm = TRUE),
    date_breaks = "5 years",
    date_labels = "%Y",
    expand = c(0, 0)) +  # fixes 2000 and 2026
  annotate("text",
           x = min(olr_NOAA_1974_2026$date, na.rm = TRUE),
           y = max(olr_NOAA_1974_2026$olr_ano, na.rm = TRUE),
           label = "Suppressed convection",
           hjust = 0,
           color = "red",
           size = 5) +
  
  annotate("text",
           x = min(olr_NOAA_1974_2026$date, na.rm = TRUE),
           y = min(olr_NOAA_1974_2026$olr_ano, na.rm = TRUE),
           label = "Enhanced convection",
           hjust = 0,
           color = "blue",
           size = 5) +
  labs(title = "OLR Anomalies",
       x = "Year",
       y = "OLR Anomaly") +
  theme_bw() +
  theme(axis.text.y = element_text(size = 20),
        axis.title.y = element_text(size = 20, margin = margin(r = 15)),
        axis.text.x = element_text(size = 30, angle = 45, margin = margin(t = 20)),
        axis.title.x = element_text(size = 20, margin = margin(t = 15)),
        title = element_text(size = 20, family = "serif"),
        text  = element_text(family = "serif"))


ggsave(OLR_ano_plot, filename = file.path(plot_path, "OLR_ano_1974-2026_by_month.png"), width = 1250, height = 650, units = "px", dpi=96)


#-------------------------------------------------------------------------------
# RONI Data (Seasonal dataset)

# Arrange data set to plot 

RONI_NOAA_1950_2026 <- RONI_NOAA_1950_2026 %>%
  mutate(month = case_when(
    season == "DJF" ~ 1,
    season == "JFM" ~ 2,
    season == "FMA" ~ 3,
    season == "MAM" ~ 4,
    season == "AMJ" ~ 5,
    season == "MJJ" ~ 6,
    season == "JJA" ~ 7,
    season == "JAS" ~ 8,
    season == "ASO" ~ 9,
    season == "SON" ~ 10,
    season == "OND" ~ 11,
    season == "NDJ" ~ 12
  ),
  date = as.Date(paste(year, month, "01", sep = "-")))

# RONI Plot

RONI_plot <- ggplot(RONI_NOAA_1950_2026, aes(x = date, y = roni)) +
  geom_line(color = "darkgreen", size = 1) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_date(
    limits = range(RONI_NOAA_1950_2026$date, na.rm = TRUE),
    date_breaks = "5 years",
    date_labels = "%Y",
    expand = c(0, 0)) +  # fixes 2000 and 2026
  labs(title = "RONI Index",
       x = "Year",
       y = "RONI") +
  theme_bw() +
  theme(axis.text.y = element_text(size = 20),
        axis.title.y = element_text(size = 20, margin = margin(r = 15)),
        axis.text.x = element_text(size = 30, angle = 45, margin = margin(t = 20)),
        axis.title.x = element_text(size = 20, margin = margin(t = 15)),
        title = element_text(size = 20, family = "serif"),
        text  = element_text(family = "serif"))

ggsave(RONI_plot, filename = file.path(plot_path, "RONI_1950-2026_by_month.png"), width = 1250, height = 650, units = "px", dpi=96)


#-------------------------------------------------------------------------------
# Multivariate ENSO Index Version 2 (MEI.v2) (data is organized in two months)

# Arrange data set to plot 
MEI_NOAA_1979_2026 <- MEI_NOAA_1979_2026 %>%
  mutate(month_num = case_when(
    month == "DJ" ~ 1,
    month == "JF" ~ 2,
    month == "FM" ~ 3,
    month == "MA" ~ 4,
    month == "AM" ~ 5,
    month == "MJ" ~ 6,
    month == "JJ" ~ 7,
    month == "JA" ~ 8,
    month == "AS" ~ 9,
    month == "SO" ~ 10,
    month == "ON" ~ 11,
    month == "ND" ~ 12
  ),
  date = as.Date(paste(year, month_num, "01", sep = "-")))

MEI_plot <- ggplot(MEI_NOAA_1979_2026, aes(x = date, y = mei)) +
  geom_line(color = "darkgreen", size = 1) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_date(
    limits = range(MEI_NOAA_1979_2026$date, na.rm = TRUE),
    date_breaks = "5 years",
    date_labels = "%Y",
    expand = c(0, 0)) +  # fixes 2000 and 2026
  labs(title = "MEI Index",
       x = "Year",
       y = "MEI") +
  theme_bw() +
  theme(axis.text.y = element_text(size = 20),
        axis.title.y = element_text(size = 20, margin = margin(r = 15)),
        axis.text.x = element_text(size = 30, angle = 45, margin = margin(t = 20)),
        axis.title.x = element_text(size = 20, margin = margin(t = 15)),
        title = element_text(size = 20, family = "serif"),
        text  = element_text(family = "serif"))

ggsave(MEI_plot, filename = file.path(plot_path, "MEI_1979-2026_by_month.png"), width = 1250, height = 650, units = "px", dpi=96)


#-------------------------------------------------------------------------------
# AMO Data (monthly dataset)

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# amo plot

# Arrange data set to plot (wide to long, month names to numbers)
amo_long <- amo_NOAA_1856_2022 %>%
  pivot_longer(-YEAR, names_to = "month", values_to = "amo") %>%
  mutate(month = match(month, c("JAN","FEB","MAR","APR","MAY","JUN",
                                "JUL","AUG","SEP","OCT","NOV","DEC"))) %>%
  rename(year = YEAR)

# Create date column
amo_long$date <- as.Date(
  paste(amo_long$year,
        amo_long$month, "01", sep = "-")
)

amo_plot <- ggplot(amo_long, aes(x = date, y = amo)) +
  geom_line(color = "darkgreen", linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_date(
    limits = range(amo_long$date, na.rm = TRUE),
    date_breaks = "20 years",
    date_labels = "%Y",
    expand = c(0, 0)) +  # fixes 2000 and 2026
  labs(title = "Atlantic Multidecadal Oscillation (AMO)",
       x = "Year",
       y = "AMO") +
  theme_bw() +
  theme(axis.text.y = element_text(size = 20),
        axis.title.y = element_text(size = 20, margin = margin(r = 15)),
        axis.text.x = element_text(size = 30, angle = 45, margin = margin(t = 20)),
        axis.title.x = element_text(size = 20, margin = margin(t = 15)),
        title = element_text(size = 20, family = "serif"),
        text  = element_text(family = "serif"))

amo_plot

ggsave(amo_plot, filename = file.path(plot_path, "AMO_1856-2022_by_month.png"), width = 1250, height = 650, units = "px", dpi=96)
