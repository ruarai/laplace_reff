model <- mock_model(c("z.1", "z.2", "mu", "alpha"), NULL, NULL, NULL)

test_that("outer names map to unconstrained positions in the order given", {
  expect_equal(outer_index(model, c("alpha", "mu")), c(4, 3))
  expect_equal(outer_index(model, "z"), 1:2)
  expect_equal(outer_index(model, "z.2"), 2)
})

test_that("invalid outer sets are rejected", {
  expect_error(outer_index(model, "nope"), "Unknown outer parameter")
  expect_error(outer_index(model, character()), "at least one")
  expect_error(outer_index(model, c("z", "z.1")), "more than once")
  expect_error(outer_index(model, c("z", "mu", "alpha")), "nothing to integrate")
})
