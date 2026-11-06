model <- mock_model(c("z.1", "z.2", "mu", "alpha"), NULL, NULL, NULL)

test_that("outer names map to unconstrained positions in the order given", {
  expect_equal(get_outer_param_indices(model, c("alpha", "mu")), c(4, 3))
  expect_equal(get_outer_param_indices(model, "z"), 1:2)
  expect_equal(get_outer_param_indices(model, "z.2"), 2)
})

test_that("invalid outer sets are rejected", {
  expect_error(get_outer_param_indices(model, "nope"),
               "Unknown outer parameter")
  expect_error(get_outer_param_indices(model, character()), "at least one")
  expect_error(get_outer_param_indices(model, c("z", "z.1")), "more than once")
  expect_error(get_outer_param_indices(model, c("z", "mu", "alpha")),
               "nothing to integrate")
})
