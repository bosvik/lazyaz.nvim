return {
  {
    name = "health module loads without running checks",
    fn = function(t)
      require("lazyaz.health")
      t.ok(true)
    end,
  },
}
