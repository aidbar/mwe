# How to run: open Julia REPL, and run this: include("path/to/file/filename.jl")
using Agents
using CairoMakie
using WGLMakie, JSServe
#using InteractiveDynamics
using LibPQ
using Tables
using JSON3
#include("BuildingMapSpace.jl")

# Define an agent type
mutable struct MyAgent <: AbstractAgent
    id::Int  # The identifier number of the agent - mandatory field
    pos::NTuple{2, Int} # The x, y location of the agent on a 2D grid - madatory field
    name::String
    something::Float64
end

function Agents.agent2string(agent::MyAgent)
    """
    Agent info:
    Name = $(agent.name)
    ID in simulation = $(agent.id)
    Position = $(agent.pos[1])
    Something = $(agent.something)
    """
end

conf = JSON3.read("mapconfig.json")
floors = conf["floors"]
floordata = conf["floor_data"]
println("reading done")

buildingmap::Array{BuildingMapSpaceFloor} = []

#=#import Agents.agent2string
function Agents.agent2string(agent::MyAgent)
    #="""
    Name = $(agent.name)
    Position = $(agent.pos[1])
    Agent ID in visualization = $(agent.id)
    Something = $(agent.something)
    """=#
    #=333=#
    #=agentstring = "Name = " * agent.name * " Position = " * string(agent.pos[1]) * " " *
    string(agent.pos[2]) * " Agent ID in visualisation = " * string(agent.id) * "Something = " * string(agent.something)
    println(agentstring)
    return agentstring=#
    "test"
end=#

for i in 1:floors
    fl = "floor" * string(i)
    current_floor = conf["floor_data"][fl]
    println(current_floor)
    rooms::Array{BuildingMapSpaceRoom} = []
    for j in 1:length(current_floor)
        r = "room" * string(j)
        println(current_floor[r])
        name = current_floor[r]["name"]
        points = current_floor[r]["points"]
        positions::Array{BuildingMapSpacePosition} =  []
        for k in 1:length(points)
            x = parse(Int, points[k]["x"])
            y = parse(Int, points[k]["y"])
            position = BuildingMapSpacePosition(x, y, -1)
            push!(positions, position)
        end
        room = BuildingMapSpaceRoom(name, positions)
        push!(rooms, room)
    end
    floor = BuildingMapSpaceFloor(rooms)
    push!(buildingmap, floor)
end

print(buildingmap)

#=buildingmap = Matrix{Any}(undef, 5, 5)
buildingmap = fill!(buildingmap, [])
space = BuildingMapSpace(buildingmap)
println("width is " * string(space.width) * ", heigth is " * string(space.heigth))=#
space = BuildingMapSpace(buildingmap)

# Create the agent-based model
properties = Dict(:min_for_something => 3)
model = ABM(MyAgent, space; properties) #; properties

agent_array = []

current_cycle = 1

last_cycle = -1

database_table_name = "schema.test_logs_mas3"

# Establish connection
conn = LibPQ.Connection("dbname=etairos_test user=postgres password=password")
#= conn = LibPQ.Connection(
    host = "localhost",
    port = 5432,
    dbname = "etairos_test",
    user = "postgres",
    password = "password"
) =#
#open!(conn)

agents_query = "SELECT DISTINCT agentname FROM " * database_table_name

res = execute(conn, agents_query)

agents_database = columntable(res)

println(agents_database)

agent_array = collect(skipmissing(agents_database[1]))

println(agent_array)

last_cycle_query = "SELECT MAX(cycle::int) FROM " * database_table_name

res = execute(conn, last_cycle_query)

last_cycle_database = columntable(res)

println(last_cycle_database)

last_cycle = last_cycle_database[1][1]

println(last_cycle)

# Create agents and add them to the model
for i in 1:length(agent_array)
    print(string(i) * " " * agent_array[i])
    pos1 = 1
    pos2 = rand(1:10)
    while (is_position_occupied(model, (pos1, pos2)))
        pos2 = rand(1:10)
    end
    agent = MyAgent(i, (pos1, pos2), agent_array[i], pos1) #(rand(Int, 1)[1], rand(Int, 1)[1])
    println(string(agent))
    add_agent_pos!(agent, model) #model, agent
end

# Create the visualization scene
scene = Scene(resolution = (500, 500))

# Set up the initial plot
#scatter!(scene, [agent.x], [], markersize = 5, color = :red)

function agent_step!(agent, model)
    #=for neighbor in nearby_agents(agent, model)
        println("agent_step! in action")
        println(current_cycle)
        if agent.something > neighbor.something
            move_agent_single!(agent, model)
        end
    end=#
    println("agent_step! in action for agent " * agent.name * " in cycle " * string(current_cycle))
    if current_cycle > last_cycle
        return
    end
    currentcycledata = getcurrentcycledata(agent)
    if length(currentcycledata) > 0
        println("*")
        println(currentcycledata[1][:type])
        for i in 1:length(currentcycledata)
            if !ismissing(currentcycledata[i][:agentname])
                if(currentcycledata[i][:agentname]) == agent.name
                    if length(currentcycledata[i][:action]) > 0
                        comparison = cmp(currentcycledata[i][:action][1:4], "move")
                    else
                        comparison = -1
                    end

                    if comparison == 0
                        println("move action to be taken to agent " * agent.name)
                        println("agent moved: ")
                        print(currentcycledata[i][:agentname])
                        pos1 = 1
                        pos2 = rand(1:10)
                        while (is_position_occupied(model, (pos1, pos2)))
                            pos2 = rand(1:10)
                        end
                        move_agent!(agent, (pos1, pos2), model)

                    end
                end
            end
        end
    end
    #move_agent_single!(agent, model)
    #-global current_cycle += 1
end

function getcurrentcycledata(agent)
    next_cycle = current_cycle + 1
    query = "SELECT * FROM " * database_table_name * " WHERE agentname = '" * agent.name * "' AND id >= (SELECT id FROM " * database_table_name * " WHERE cycle = '" * string(current_cycle) * "') AND id < (SELECT id FROM " * database_table_name * " WHERE cycle = '" * string(next_cycle) * "')"
    cycle_info_query = execute(conn, query)
    currentcycledata = rowtable(cycle_info_query)
    println(currentcycledata)
    return currentcycledata
end

# We define a dictionary that maps some model-level parameters to a range of potential
# values, so that we can interactively change them.
parange = Dict(:min_for_something => 0:8)

#runs after every agent has ran its agent_step!
function model_step!(model)
    global current_cycle += 1
end

using GLMakie
using Plots
using LinearAlgebra
import ImageMagick
using FileIO
function static_preplot!(ax, model)
    #=heightmap = floor.(Int, convert.(Float64, load(download("https://raw.githubusercontent.com/JuliaDynamics/JuliaDynamics/master/videos/agents/rabbit_fox_hawk_heightmap.png"))) * 39) .+ 1
    println(:terrain)
    GLMakie.surface!(
        ax,
        (100/205):(100/205):100,
        (100/205):(100/205):100,
        heightmap;
        colormap = :terrain
    )=#
    println(ax.parent.scene)
    path = "d:/test-specification/julia/example1111.png"
    img = load(assetpath(path))
    #---image!(ax, img, inspectable = false)
    #image!(ax.parent.scene, rotr90(img), inspectable = false)
    image!(ax, 0..1, 0..1, rotr90(img), space = :relative, translation = Vec3f(0, 0, -10), inspectable = false)
end
# We also define the data we want to collect and interactively explore, and also
# some labels for them, for shorter names (since the defaults can get large)
using Statistics: mean
x(agent) = agent.something
adata = [(:something, sum), (x, mean)]
alabels = ["something", "avg. x"]
mlabels = ["mlabel1", "mlabel2"]
#using GLMakie # using a different plotting backend that enables interactive plots
#using Plots
GLMakie.activate!()
global fig, ax, abmobs = abmplot(
        model;
        agent_step! = agent_step!, model_step! = model_step!, params = parange, enable_inspection = true,
        ac = "#338c54", am = :diamond, as = 15, static_preplot! = static_preplot!
    )
fig
#wait(display(figure))

WGLMakie.activate!()
JSServe.browser_display()
disp = App() do session::Session
    #println(DOM.div(figure))
    #println(DOM.div(abmobs))
    #println(DOM.div("aaaa"))
    #println(DOM.div("<div>ueifhiuefh</div>"))
    return DOM.div(DOM.div(fig))
end

display(disp) #wait(display(figure)) =#