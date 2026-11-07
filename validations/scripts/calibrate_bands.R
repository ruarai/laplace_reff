# calibrate_bands.R: how often do the bands say "not good" when laml agrees
# exactly with the reference? Only Monte Carlo noise differs between the samples.
source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "common.R"))
bands <- jsonlite::fromJSON(file.path(root, "bands.json"), simplifyVector = TRUE,
                            simplifyDataFrame = FALSE, simplifyMatrix = FALSE)
set.seed(1)
reps <- 400
for (shape in c("normal", "gamma(4)")) {
  sampler <- if (shape == "normal") stats::rnorm else function(n) stats::rgamma(n, 4)
  for (k in c(2, 10, 26, 66)) {
    labels <- replicate(reps, {
      m <- vapply(seq_len(k), function(j) {
        ref <- sampler(1e4)
        v <- variable_metrics(sampler(1000), ref)
        c(v$mean_err, v$sd_ratio, v$w1)
      }, numeric(3))
      c(label_mean_sd(m[1, ], m[2, ], bands$mean_sd), label_w1(m[3, ], bands$w1), max(m[3, ]))
    })
    cat(sprintf("%-9s k=%2d  mean/SD not good %.3f, not acceptable %.3f | W1 not good %.3f, not acceptable %.3f | median worst W1 %.3f\n",
                shape, k, mean(labels[1, ] != "good"), mean(labels[1, ] == "poor"),
                mean(labels[2, ] != "good"), mean(labels[2, ] == "poor"),
                median(as.numeric(labels[3, ]))))
  }
}
