module getDeps

using IntegrationTests
using Pkg

include(joinpath(dirname(@__FILE__), "prepareIntegrationTest.jl"))

# see README.md
if !isinteractive()
    tmp_path = mktempdir()
    prepareIntegrationTest.create_package_eco_system(tmp_path)

    # extra Project.toml to generate dependency graph for the whole project
    Pkg.activate(joinpath(tmp_path, "MyPkgMeta"))
    depending_packages = IntegrationTests.depending_projects("MyPkgC", r"^MyPkg*")

    # compare with expected result
    # needs to be negated, because true would result in error code 1
    exit(!(sort(depending_packages) == sort(["MyPkgA", "MyPkgB"])))
end

end
