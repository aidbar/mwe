using Agents
#include("BuildingMapSpace.jl")

#= # Create a building map
map = Matrix{Any}(undef, 5, 5)
map = fill!(map, [])
#=map = [
    [] [] [] [] [];
    [] [] [] [] [];
    [] [] [] [] [];
    [] [] [] [] [];
    [] [] [] [] []
]=#
println(map)
width, height = size(map)=#

# Create a building map
pos1 = BuildingMapSpacePosition(1, 1, -1)
pos2 = BuildingMapSpacePosition(1, 2, -1)
pos3 = BuildingMapSpacePosition(1, 3, -1)

room = BuildingMapSpaceRoom("room_name1", Array{BuildingMapSpacePosition}([pos1, pos2, pos3]))

floor = BuildingMapSpaceFloor(Array{BuildingMapSpaceRoom}([room]))

space = BuildingMapSpace(Array{BuildingMapSpaceFloor}([floor]))

#= # Create a BuildingMapSpace instance
space = BuildingMapSpace(map) =#

# Define an agent type
mutable struct Person <: AbstractAgent
    id::Int
    pos::NTuple{2, Int}
end

# Create an agent and set its initial position
agent = Person(1, (1, 1))
#=agent1 = Person(2, (1, 1))
agent2 = Person(3, (3, 3))
agent3 = Person(4, (5, 5))=#

model = ABM(Person, space)

#= # Interact with the space
println(Agents.inbounds(space, (2, 2)))  # true
println(Agents.isoccupied(space, (3, 3)))  # true
println(Agents.distance(space, (2, 2), (4, 4)))  # 4 =#

println(random_position(model))
println(Agents.add_agent_to_space!(agent, model))
println(Agents.remove_agent_from_space!(agent, model))

Agents.add_agent_to_space!(agent, model)
#=add_agent_to_space!(agent1, model)
add_agent_to_space!(agent2, model)
add_agent_to_space!(agent3, model)=#

println(nearby_ids(BuildingMapSpacePosition(1, 1, -1), model, 1))
println(nearby_positions(BuildingMapSpacePosition(1, 1, -1), model, 1))
#
