import Term.Trees: Tree

# set environment variable PRINTTREE=1 to visualize the project trees of the testsets
function printTree()::Bool
    return parse(Bool, get(ENV, "PRINTTREE", "0"))
end

@testset "direct dependency to main" begin
    project_tree = Dict("MyMainProject.jl 1.0.0" => Dict("MyDep1.jl 1.0.0" => Dict()))

    if printTree()
        print(Tree(project_tree; name="direct dependency to main"))
    end

    # dependency exist and prefix is correct
    @test IntegrationTests.depending_projects(
        "MyDep1.jl", ["MyMainProject.jl"], project_tree
    ) == ["MyMainProject.jl"]
    # dependency does not exist and prefix is correct
    @test isempty(
        IntegrationTests.depending_projects("MyDep2.jl", "MyMainProject.jl", project_tree)
    )
    # dependency exist and prefix is incorrect
    @test isempty(
        IntegrationTests.depending_projects("MyDep1.jl", "ExternProject.jl", project_tree)
    )
    # dependency does not exist and prefix is incorrect
    @test isempty(
        IntegrationTests.depending_projects("MyDep2.jl", "ExternProject.jl", project_tree)
    )
end

@testset "test package filter api" begin
    project_tree = Dict(
        "MyMainProject.jl 1.0.0" => Dict(
            "MyDep1.jl 1.0.0" => Dict(
                "YourDep1.jl 1.0.0" => Dict("MyDep3.jl 1.0.0" => Dict()),
                "MyDep2.jl 1.0.0" => Dict(
                    "ForeignDep1.jl 1.0.0" => Dict(Dict("MyDep3.jl 1.0.0" => Dict())),
                ),
            ),
            "yourDep2.jl 1.0.0" => Dict("MyDep1.jl 1.0.0" => Dict()),
        ),
    )
    if printTree()
        print(Tree(project_tree; name="test package filter api"))
    end

    @testset "single package name" begin
        @test sort(depending_projects("MyDep1.jl", "", project_tree)) ==
            sort(["MyMainProject.jl", "yourDep2.jl"])

        @test sort(depending_projects("MyDep1.jl", "MyMainProject.jl", project_tree)) ==
            sort(["MyMainProject.jl"])

        @test sort(depending_projects("yourDep2.jl", "MyMainProject.jl", project_tree)) ==
            sort(["MyMainProject.jl"])
    end

    @testset "regex" begin
        @test sort(depending_projects("MyDep2.jl", r"My*", project_tree)) ==
            sort(["MyDep1.jl"])

        @test sort(depending_projects("MyDep2.jl", r"MyDep*", project_tree)) == sort([])
        @test sort(
            depending_projects("MyDep2.jl", r"MyDep*|^MyMainProject.jl$", project_tree)
        ) == sort(["MyDep1.jl"])

        @test sort(depending_projects("MyDep1.jl", r"^MyMainProject.jl$", project_tree)) ==
            sort(["MyMainProject.jl"])

        @test sort(
            depending_projects(
                "MyDep1.jl", r"^MyMainProject.jl$|^yourDep2.jl$", project_tree
            ),
        ) == sort(["MyMainProject.jl", "yourDep2.jl"])

        @test sort(
            depending_projects("MyDep3.jl", r"^MyMainProject.jl$|^MyDep*", project_tree)
        ) == sort([])

        @test sort(
            depending_projects(
                "MyDep3.jl", r"^MyMainProject.jl$|^MyDep*|^Foreign*", project_tree
            ),
        ) == sort(["ForeignDep1.jl"])

        @test sort(
            depending_projects(
                "MyDep3.jl", r"^MyMainProject.jl$|^MyDep*|^Your*", project_tree
            ),
        ) == sort(["YourDep1.jl"])

        @test sort(
            depending_projects(
                "MyDep3.jl", r"^MyMainProject.jl$|^MyDep*|^Foreign*|^Your*", project_tree
            ),
        ) == sort(["ForeignDep1.jl", "YourDep1.jl"])

        @test sort(depending_projects("MyDep1.jl", r"", project_tree)) ==
            sort(["MyMainProject.jl", "yourDep2.jl"])
    end

    @testset "list of package names" begin
        @test sort(depending_projects("MyDep1.jl", ["MyMainProject.jl"], project_tree)) ==
            sort(["MyMainProject.jl"])

        @test sort(
            depending_projects("MyDep2.jl", ["MyMainProject.jl", "MyDep1.jl"], project_tree)
        ) == sort(["MyDep1.jl"])

        @test sort(
            depending_projects(
                "MyDep3.jl",
                ["MyMainProject.jl", "MyDep1.jl", "ForeignDep1.jl", "MyDep3.jl"],
                project_tree,
            ),
        ) == sort([])

        @test sort(
            depending_projects(
                "MyDep3.jl",
                [
                    "MyMainProject.jl",
                    "MyDep1.jl",
                    "MyDep2.jl",
                    "ForeignDep1.jl",
                    "MyDep3.jl",
                ],
                project_tree,
            ),
        ) == sort(["ForeignDep1.jl"])

        @test sort(
            depending_projects(
                "MyDep3.jl",
                [
                    "YourDep1.jl",
                    "MyMainProject.jl",
                    "MyDep1.jl",
                    "MyDep2.jl",
                    "ForeignDep1.jl",
                    "MyDep3.jl",
                ],
                project_tree,
            ),
        ) == sort(["YourDep1.jl", "ForeignDep1.jl"])

        # using strings and regex in a vector is not allowed
        # use instead a single regex
        @test_throws MethodError depending_projects(
            "MyDep2.jl", ["MyMainProject.jl", r"MyDep1.jl"], project_tree
        )

        @test_throws ArgumentError depending_projects(
            "MyDep2.jl", Vector{String}(), project_tree
        )
    end
end

@testset "complex dependencies" begin
    #! format: off
    project_tree = Dict("MyMainProject.jl 1.0.0" =>
                        Dict("MyDep1.jl 1.0.0"      => Dict(),
                             "MyDep2.jl 1.0.0"      => Dict("MyDep3.jl 1.0.0" => Dict(),
                                                            "ForeignDep1.jl 1.0.0" => Dict()),
                             "ForeignDep2.jl 1.0.0" => Dict("ForeignDep3.jl 1.0.0" => Dict(),
                                                            "ForeignDep4.jl 1.0.0" => Dict()),
                             "MyDep4.jl 1.0.0"      => Dict("MyDep5.jl 1.0.0" => Dict("MyDep3.jl 1.0.0" => Dict())),
                             "ForeignDep2.jl 1.0.0" => Dict("MyDep5.jl 1.0.0" => Dict("MyDep3.jl 1.0.0" => Dict()),
                                                            "MyDep3.jl 1.0.0" => Dict(),
                                                            "MyDep6.jl 1.0.0" => Dict("MyDep3.jl 1.0.0" => Dict())),
                             "MyDep7.jl 1.0.0"      => Dict("MyDep5.jl 1.0.0" => Dict("MyDep3.jl 1.0.0" => Dict()),
                                                            "MyDep3.jl 1.0.0" => Dict()),
                            )
                        )
    #! format: on
    if printTree()
        print(Tree(project_tree; name="complex dependencies"))
    end

    package_filter = [
        "MyMainProject.jl",
        "MyDep1.jl",
        "MyDep2.jl",
        "MyDep3.jl",
        "MyDep4.jl",
        "MyDep5.jl",
        "MyDep6.jl",
        "MyDep7.jl",
    ]

    # sort all vectors to guaranty the same order -> guaranty is not important for the actual result, onyl for comparison
    @test sort(
        IntegrationTests.depending_projects("MyDep1.jl", package_filter, project_tree)
    ) == sort(["MyMainProject.jl"])
    @test sort(
        IntegrationTests.depending_projects("MyDep2.jl", package_filter, project_tree)
    ) == sort(["MyMainProject.jl"])
    # MyDep5.jl should only appears one time -> MyDep4.jl and MyDep7.jl has the same MyDep5.jl dependency
    @test sort(
        IntegrationTests.depending_projects("MyDep3.jl", package_filter, project_tree)
    ) == sort(["MyDep2.jl", "MyDep5.jl", "MyDep7.jl"])
    @test sort(
        IntegrationTests.depending_projects("MyDep5.jl", package_filter, project_tree)
    ) == sort(["MyDep4.jl", "MyDep7.jl"])
    # cannot find MyDep6.jl, because it is only a dependency of a foreign package
    @test isempty(
        IntegrationTests.depending_projects("MyDep6.jl", package_filter, project_tree)
    )
    @test isempty(IntegrationTests.depending_projects("MyDep3.jl", ["Foo"], project_tree))
end

@testset "circular dependency" begin
    # I cannot create a real circular dependency with this data structur, but if Circulation appears in an output, we passed MyDep1.jl and MyDep2.jl two times, which means it is a circle
    project_tree = Dict(
        "MyMainProject.jl 1.0.0" => Dict(
            "MyDep1.jl 1.0.0" => Dict(
                "MyDep2.jl 1.0.0" => Dict(
                    "MyDep1.jl 1.0.0" => Dict(
                        "MyDep2.jl 1.0.0" => Dict("Circulation" => Dict())
                    ),
                ),
            ),
        ),
    )

    if printTree()
        print(Tree(project_tree; name="circular dependencies"))
    end

    package_filter = ["MyMainProject.jl", "MyDep1.jl", "MyDep2.jl"]

    @test sort(
        IntegrationTests.depending_projects("MyDep1.jl", package_filter, project_tree)
    ) == sort(["MyMainProject.jl", "MyDep2.jl"])
    @test sort(
        IntegrationTests.depending_projects("MyDep2.jl", package_filter, project_tree)
    ) == sort(["MyDep1.jl"])
    @test isempty(IntegrationTests.depending_projects("MyDep2.jl", ["Foo"], project_tree))
    @test isempty(
        IntegrationTests.depending_projects("Circulation", package_filter, project_tree)
    )
end
