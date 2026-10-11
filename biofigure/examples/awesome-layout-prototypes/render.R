#!/usr/bin/env Rscript
# Independent simulated layout probes. No source-paper data or artwork is used.
suppressPackageStartupMessages(library(ggplot2))
suppressPackageStartupMessages(library(patchwork))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("usage: Rscript render.R OUTPUT_DIR")
out <- args[[1L]]
dir.create(out, recursive = TRUE, showWarnings = FALSE)
set.seed(20260923)

base_theme <- theme_classic(base_size = 11) +
  theme(plot.title = element_text(face = "bold", size = 12),
        plot.subtitle = element_text(colour = "#55616E", size = 9),
        axis.title = element_text(size = 10),
        strip.background = element_rect(fill = "#F3F6F8", colour = NA),
        strip.text = element_text(face = "bold"),
        panel.spacing = grid::unit(5, "mm"),
        legend.position = "bottom")
case_colors <- c(Alpha = "#E7A34F", Beta = "#D9C66D", Delta = "#65B7A7", Omicron = "#CF6595")

# 1: temporal curve + aligned categorical bubble track.
dates <- seq(as.Date("2020-04-01"), as.Date("2022-03-01"), by = "month")
regions <- c("Region A", "Region B", "Region C")
time <- expand.grid(date = dates, region = regions, KEEP.OUT.ATTRS = FALSE)
time$month <- as.numeric(time$date - min(dates)) / 30.4
offset <- match(time$region, regions) * 1.5
time$cases <- pmax(0.1, 0.5 + 8 * exp(-((time$month - 8 - offset) / 4)^2) +
                   14 * exp(-((time$month - 19 + offset) / 3.4)^2) +
                   runif(nrow(time), 0, 1.8))
bubble <- expand.grid(date = dates[seq(1, length(dates), by = 2)],
                      region = regions, lineage = names(case_colors),
                      KEEP.OUT.ATTRS = FALSE)
bubble$month <- as.numeric(bubble$date - min(dates)) / 30.4
centers <- c(Alpha = 5, Beta = 9, Delta = 16, Omicron = 22)
bubble$count <- round(180 * exp(-((bubble$month - centers[bubble$lineage]) / 3.3)^2) *
                      runif(nrow(bubble), 0.45, 1.25))
bubble <- bubble[bubble$count > 3, ]
top <- ggplot(time, aes(date, cases, group = region)) +
  geom_ribbon(aes(ymin = 0.1, ymax = cases), fill = "#83B7AD", alpha = 0.22) +
  geom_line(colour = "#287F79", linewidth = 0.55) +
  scale_y_log10(limits = c(0.1, 100)) +
  facet_wrap(~region, nrow = 1) +
  labs(y = "Cases per million", x = NULL) + base_theme +
  theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())
bottom <- ggplot(bubble, aes(date, lineage)) +
  geom_hline(yintercept = 1:4, colour = "#E6E9EA", linewidth = 0.3) +
  geom_point(aes(size = count, fill = lineage), shape = 21,
             colour = "#48525C", stroke = 0.2, alpha = 0.8) +
  scale_size_area(max_size = 8, breaks = c(25, 100, 175)) +
  scale_fill_manual(values = case_colors) +
  facet_wrap(~region, nrow = 1) +
  scale_x_date(date_breaks = "6 months", date_labels = "%b %Y") +
  labs(y = "Category", x = "Date", size = "Observations", fill = "Category") + base_theme +
  theme(axis.text.x = element_text(angle = 35, hjust = 1))
p_time <- (top / bottom + plot_layout(heights = c(1, 1.1), guides = "collect")) &
  theme(legend.position = "bottom")
p_time <- p_time + plot_annotation(title = "Temporal curve and size-coded category track",
                                   subtitle = "SIMULATED DATA · structural prototype, not a paper reproduction")
ggsave(file.path(out, "temporal_bubble.png"), p_time, width = 11.8, height = 6.4, dpi = 180, bg = "white")

# 2: four-panel longitudinal comparison with units and individual observations.
groups <- c("Low dose", "High dose", "Control")
group_colors <- c("Low dose" = "#DF9B56", "High dose" = "#6CAF9A", Control = "#C97D82")
raw <- expand.grid(target = c("Target A", "Target B"), day = c(28, 90, 180, 360),
                   group = groups, individual = seq_len(14), KEEP.OUT.ATTRS = FALSE)
raw$log_titre <- log2(900) - log2(raw$day / 28) * 0.4 +
  c("Low dose" = 0, "High dose" = 0.45, Control = -1.5)[raw$group] +
  ifelse(raw$target == "Target B", -2.0, 0) + rnorm(nrow(raw), sd = 0.7)
raw$titre <- 2^raw$log_titre
stopifnot(mean(raw$titre[raw$target == "Target A"]) >
          mean(raw$titre[raw$target == "Target B"]))
summary <- aggregate(log_titre ~ target + day + group, raw,
                     function(x) c(mean = mean(x), se = sd(x) / sqrt(length(x))))
summary <- data.frame(summary[c("target", "day", "group")], summary$log_titre)
summary$estimate <- 2^summary$mean
summary$lower <- 2^(summary$mean - 1.96 * summary$se)
summary$upper <- 2^(summary$mean + 1.96 * summary$se)
group_offset <- c("Low dose" = -0.22, "High dose" = 0, Control = 0.22)
summary$xpos <- match(summary$day, sort(unique(summary$day))) + group_offset[summary$group]
raw$xpos <- match(raw$day, sort(unique(raw$day))) + group_offset[raw$group] +
  runif(nrow(raw), -0.045, 0.045)
one_target <- function(target) {
  a <- raw[raw$target == target, ]
  b <- summary[summary$target == target, ]
  upper <- ggplot(b, aes(xpos, estimate, colour = group)) +
    geom_pointrange(aes(ymin = lower, ymax = upper), linewidth = 0.5) +
    geom_hline(yintercept = 20, linetype = "dotted", colour = "#59636C") +
    scale_y_log10() + scale_colour_manual(values = group_colors) +
    guides(colour = "none") +
    scale_x_continuous(breaks = 1:4, labels = c(28, 90, 180, 360), limits = c(0.55, 4.45)) +
    labs(title = target, x = NULL, y = "Geometric mean titre") + base_theme +
    theme(legend.position = "none")
  lower <- ggplot(a, aes(xpos, titre, colour = group)) +
    geom_point(alpha = 0.48, size = 0.7) +
    geom_line(data = b, aes(x = xpos, y = estimate, group = group),
              linewidth = 0.5) +
    geom_hline(yintercept = 20, linetype = "dotted", colour = "#59636C") +
    scale_y_log10() + scale_colour_manual(values = group_colors) +
    scale_x_continuous(breaks = 1:4, labels = c(28, 90, 180, 360), limits = c(0.55, 4.45)) +
    labs(x = "Days after intervention", y = "Individual titre", colour = "Group") + base_theme
  upper / lower + plot_layout(heights = c(0.9, 1.1))
}
p_group <- ((one_target("Target A") | one_target("Target B")) +
              plot_layout(guides = "collect")) & theme(legend.position = "bottom")
p_group <- p_group + plot_annotation(title = "Longitudinal group comparison",
                                     subtitle = "SIMULATED DATA · intervals are 1.96 SE on log2 scale; no significance brackets")
ggsave(file.path(out, "longitudinal_comparison.png"), p_group, width = 10.8, height = 7.2, dpi = 180, bg = "white")

# 3: two-panel bubble regression; displayed statistics are computed from these data.
responses <- c("Response 1", "Response 2")
scatter <- expand.grid(response = responses, id = seq_len(42), KEEP.OUT.ATTRS = FALSE)
scatter$x <- runif(nrow(scatter), 700, 1500)
scatter$group <- sample(c("Group A", "Group B"), nrow(scatter), replace = TRUE)
scatter$weight <- runif(nrow(scatter), 1, 8)
scatter$y <- ifelse(scatter$response == "Response 1", -0.0006, 0.0005) *
  (scatter$x - 1100) + rnorm(nrow(scatter), 0, 0.43)
stopifnot(!identical(scatter$y[scatter$response == "Response 1"],
                     scatter$y[scatter$response == "Response 2"]))
scatter_colors <- c("Group A" = "#1DA7AD", "Group B" = "#E7A641")
one_response <- function(response) {
  d <- scatter[scatter$response == response, ]
  fit <- lm(y ~ x, d)
  sm <- summary(fit)
  label <- sprintf("R² = %.2f\nP = %.3f", sm$r.squared, coef(sm)[2, 4])
  ggplot(d, aes(x, y)) +
    geom_hline(yintercept = 0, linetype = "dotted", colour = "#59636C", linewidth = 0.45) +
    geom_smooth(method = "lm", formula = y ~ x, se = TRUE,
                colour = "#22272B", fill = "#CED2D5", linetype = "dashed", linewidth = 0.65) +
    geom_point(aes(size = weight, fill = group), shape = 21,
               colour = "#333A40", stroke = 0.4, alpha = 0.9) +
    annotate("label", x = 1490, y = 1.14, label = label,
             hjust = 1, vjust = 1, linewidth = 0, fill = "white", size = 3.1) +
    scale_fill_manual(values = scatter_colors) +
    scale_size_area(max_size = 7.5, limits = c(1, 8), breaks = c(2, 4, 6)) +
    coord_cartesian(xlim = c(690, 1510), ylim = c(-1.25, 1.3)) +
    labs(title = response, x = "Predictor (arbitrary units)",
         y = "Response effect", fill = "Group", size = "Weight") + base_theme
}
p_fit <- ((one_response("Response 1") | one_response("Response 2")) +
            plot_layout(guides = "collect")) & theme(legend.position = "bottom")
p_fit <- p_fit + plot_annotation(title = "Two-panel bubble regression",
                                 subtitle = "SIMULATED DATA · statistics recomputed from fitted models")
ggsave(file.path(out, "bubble_fit.png"), p_fit, width = 10.5, height = 5.2, dpi = 180, bg = "white")

cat("generated 3 simulated structural prototypes in", normalizePath(out), "\n")
