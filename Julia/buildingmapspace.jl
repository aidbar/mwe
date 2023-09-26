""" 
buildingmapspace.jl file that defines the custom agent space BuildingMapSpace.

This file should be added to the "spaces" folder of the source code of the Agents.jl package
(for example '.julia/packages/Agents/PhazO/src/spaces').

Aside from adding buildingmapspace.jl to the source code, the following source code modifications need to be implemented
in order to use BuildingMapSpace:

1. [package: Agents.jl, file: src/Agents.jl] - add `include` directive for buildingmapspace.jl:

    <...>
    include("spaces/openstreetmap.jl")
    include("spaces/buildingmapspace.jl") # <---- HERE
    include("spaces/utilities.jl")
    <...>

If using InteractiveDynamics.jl (in Julia versions older than 1.9) **** If using Agents with AgentsVisualisations (in Julia versions newer than 1.9):

2. [package: InteractiveDynamics.jl, file: src/agents/abmplot.jl **** package: Agents.jl, file: ext/AgentsVisualisations/abmplot.jl] - add Agents.BuildingMapSpace to SUPPORTED_SPACES:

    <...>
    const SUPPORTED_SPACES = Union{
        Agents.GridSpace,
        Agents.GridSpaceSingle,
        Agents.ContinuousSpace,
        Agents.OpenStreetMapSpace,
        Agents.GraphSpace,
        Agents.BuildingMapSpace # <----- HERE
    }
    <...>

3. [package: InteractiveDynamics.jl, file: src/agents/abmplot.jl **** package: Agents.jl, file: ext/AgentsVisualisations/src/abmplot.jl ] - add an `elseif` for BuildingMapSpace to the function `set_axis_limits!`:

    <...>
    elseif model.space isa Agents.ContinuousSpace
        e = model.space.extent
        o = zero.(e)
    elseif model.space isa Agents.AbstractGridSpace
        e = size(model.space) .+ 0.5
        o = zero.(e) .+ 0.5
    elseif model.space isa Agents.BuildingMapSpace # <--- HERE
        e = get_max_coordinates(model) .+ 1 # <--- HERE
        o = zero.(e) .+ 0.5 # <--- HERE
    end
    <...>

4. [package: InteractiveDynamics.jl, file: src/agents/lifting.jl *** package: Agents.jl, file: ext/AgentsVisualisations/lifting.jl] - add `agents_space_dimensionality` for BuildingMapSpace:

    <...>
    agents_space_dimensionality(::Agents.AbstractGridSpace{D}) where {D} = D
    agents_space_dimensionality(::Agents.ContinuousSpace{D}) where {D} = D
    agents_space_dimensionality(::Agents.OpenStreetMapSpace) = 2
    agents_space_dimensionality(::Agents.GraphSpace) = 2
    agents_space_dimensionality(::Agents.BuildingMapSpace) = 2 # <----- HERE
    <...>
"""

export BuildingMapSpace, BuildingMapAgent, BuildingMapSpaceFloor, BuildingMapSpaceRoom, BuildingMapSpacePosition, get_all_positions, get_max_coordinates, is_position_occupied

# a struct for storing position data
mutable struct BuildingMapSpacePosition
    x::Int
    y::Int
    agent::Int #if applicable - the id of the agent currently occupying the BuildingMapSpacePosition, if there is currently no agent in the BuildingMapSpacePosition, the 'agent' is equal to -1
end

# a struct for storing room data
struct BuildingMapSpaceRoom
    name::String
    positions::Array{BuildingMapSpacePosition}
end

# a struct for storing floor data
struct BuildingMapSpaceFloor
    rooms::Array{BuildingMapSpaceRoom}
end

struct BuildingMapSpace <: Agents.AbstractSpace #{D,P} <:Agents.AbstractGridSpace{D,P}
    #stored_ids::Vector{Int64}
    map::Array{BuildingMapSpaceFloor} #Matrix{Vector{Int64}} #::Matrix{Int64}  # array of floors of the building
    floors::Int64 #number of floors in the building
end

function BuildingMapSpace(map::Array{BuildingMapSpaceFloor}) #(map::Matrix{Any})
    floors = length(map)
    return BuildingMapSpace(map, floors)
end

@agent BuildingMapAgent NoSpaceAgent begin
    pos::NTuple{2, Int}
end


#######################################################################################
# %% IMPLEMENT
#######################################################################################
"""
    random_position(model) → pos
Return a random position in the model's space (always with appropriate Type).
"""
function Agents.random_position(model)
    rand_floor = rand(1:model.space.floors)
    chosen_floor_size = length(model.space.map[rand_floor].rooms)
    rand_room = rand(1:chosen_floor_size)
    chosen_room_positions = model.space.map[rand_floor].rooms[rand_room].positions
    rand_pos = rand(chosen_room_positions)
    return rand_pos
end

"""
    add_agent_to_space!(agent, model)
Add the agent to the underlying space structure at the agent's own position.
This function is called after the agent is already inserted into the model dictionary
and `maxid` has been updated. This function is NOT part of the public API.
"""
function Agents.add_agent_to_space!(agent, model)
    for floor in 1:model.space.floors
        for room in 1:length(model.space.map[floor].rooms)
            current_room_positions = model.space.map[floor].rooms[room].positions
            for position in 1:length(current_room_positions)
                if agent.pos[1] == current_room_positions[position].x && agent.pos[2] == current_room_positions[position].y
                    if current_room_positions[position].agent == -1
                        model.space.map[floor].rooms[room].positions[position].agent = agent.id
                    else
                        error("Error placing agent in position: position is already occupied by another agent.")
                    end
                end
            end
        end
    end
    return agent
end

"""
    remove_agent_from_space!(agent, model)
Remove the agent from the underlying space structure.
This function is called after the agent is already removed from the model container.
This function is NOT part of the public API.
"""
function Agents.remove_agent_from_space!(agent, model)
    for floor in 1:model.space.floors
        for room in 1:length(model.space.map[floor].rooms)
            current_room_positions = model.space.map[floor].rooms[room].positions
            for position in 1:length(current_room_positions)
                if agent.pos[1] == current_room_positions[position].x && agent.pos[2] == current_room_positions[position].y
                    model.space.map[floor].rooms[room].positions[position].agent = -1
                end
            end
        end
    end
    return agent
end

#######################################################################################
# %% IMPLEMENT: Neighbors and stuff
#######################################################################################
"""
    nearby_ids(position, model::ABM, r = 1) → ids

Return an iterable over the IDs of the agents within distance `r` (inclusive) from the given
`position`. The `position` must match type with the spatial structure of the `model`.

The specification of what "distance" means depends on the space. In `BuildingMapSpace`, `nearby_ids` return an iterable over IDs of agents in rooms within specified distance of `position` in both positive and negative directions on the same floor that the given position is on.

`nearby_ids` always includes IDs with 0 distance to `position`.
"""
function Agents.nearby_ids(position, model, r = 1)
    nearby_ids::Array{Int} = []
    for floor in 1:model.space.floors
        for room in 1:length(model.space.map[floor].rooms)
            current_room_positions = model.space.map[floor].rooms[room].positions
            for current_position in 1:length(current_room_positions)
                if position.x == current_room_positions[current_position].x && position.y == current_room_positions[current_position].y
                    temp = findall(i -> i.agent >=0, current_room_positions)
                    append!(nearby_ids, temp)
                    rooms_in_floor = model.space.map[floor].rooms
                    search_radius_pos = r
                    search_radius_neg = r
                    if r > length(rooms_in_floor)
                        search_radius_pos = length(rooms_in_floor)
                    end
                    if (room - r) <= 0
                        search_radius_neg = room - 1
                    end
                    for i in 1:search_radius_pos
                        if (room + i) <= length(rooms_in_floor)
                            temp = findall(i -> i.agent >=0, model.space.map[floor].rooms[room + i].positions)
                            append!(nearby_ids, temp)
                        end
                    end
                    for i in 1:search_radius_neg
                        if (room - i) <= length(rooms_in_floor)
                            temp = findall(i -> i.agent >=0, model.space.map[floor].rooms[room - i].positions)
                            append!(nearby_ids, temp)
                        end
                    end 
                end
            end
        end
    end
    return nearby_ids
end

"""
    nearby_positions(position, model::ABM{<:DiscreteSpace}, r=1; kwargs...)

Return an iterable of all positions within "radius" `r` of the given `position`
(which excludes given `position`).
The `position` must match type with the spatial structure of the `model`.

The value of `r` and possible keywords operate identically to [`nearby_ids`](@ref).

This function only exists for discrete spaces with a finite amount of positions.

    nearby_positions(position, model::ABM{<:OpenStreetMapSpace}; kwargs...) → positions
"""
function Agents.nearby_positions(position, model, r = 1)
    nearby_positions::Array{BuildingMapSpacePosition} = []
    for floor in 1:model.space.floors
        for room in 1:length(model.space.map[floor].rooms)
            current_room_positions = model.space.map[floor].rooms[room].positions
            for current_position in 1:length(current_room_positions)
                if position.x == current_room_positions[current_position].x && position.y == current_room_positions[current_position].y
                    rooms_in_floor = model.space.map[floor].rooms
                    search_radius_pos = r
                    search_radius_neg = r
                    if r > length(rooms_in_floor)
                        search_radius_pos = length(rooms_in_floor)
                    end
                    if (room - r) <= 0
                        search_radius_neg = room - 1
                    end
                    append!(nearby_positions, model.space.map[floor].rooms[room].positions)
                    for i in 1:search_radius_pos
                        if (room + i) <= length(rooms_in_floor)
                            append!(nearby_positions, model.space.map[floor].rooms[room + i].positions)
                        end
                    end
                    for i in 1:search_radius_neg
                        if (room - i) <= length(rooms_in_floor)
                            append!(nearby_positions, model.space.map[floor].rooms[room - i].positions)
                        end
                    end
                    filter!(i->i != position, nearby_positions)
                end
            end
        end
    end
    return nearby_positions
end

function get_all_positions(model::ABM{<:BuildingMapSpace})
    all_positions = []
    for floor_iter in 1:model.space.floors
        for room_iter in 1:length(model.space.map[floor_iter].rooms)
            rooms = model.space.map[floor_iter].rooms
            for position_iter in 1:length(rooms[room_iter].positions)
                push!(all_positions, rooms[room_iter].positions[position_iter])
            end
        end
    end
    return all_positions
end

function get_max_coordinates(model::ABM{<:BuildingMapSpace})
    max_x = 0
    max_y = 0
    all_positions = get_all_positions(model)
    for i in 1:length(all_positions)
        if all_positions[i].x > max_x
            max_x = all_positions[i].x
        end
        if all_positions[i].y > max_y
            max_y = all_positions[i].y
        end
    end
    return (max_x, max_y)
end

function is_position_occupied(model, positioncoords::NTuple{2, Int})
    all_positions = get_all_positions(model)
    for i in 1:length(all_positions)
        if all_positions[i].x == positioncoords[1] && all_positions[i].y == positioncoords[2]
            if all_positions[i].agent == -1
                return false
            else
                return true
            end
        end
    end
end

#######################################################################################
# %% OPTIONAL IMPLEMENT
#######################################################################################
plan_route!(agent, dest, model_or_pathfinder; kwargs...) =
    notimplemented(model_or_pathfinder)

plan_best_route!(agent, dests, model_or_pathfinder; kwargs...) =
    notimplemented(model_or_pathfinder)

# """
#     move_along_route!(agent, model, args...; kwargs...)
# Move `agent` along the route planned for it. Used in situations like path-finding
# or open street map space movement.
# """
move_along_route!(agent, model, args...; kwargs...) = notimplemented(model)

"""
    is_stationary(agent, model)
Return `true` if agent has reached the end of its route, or no route
has been set for it. Used in setups where using [`move_along_route!`](@ref) is valid.
"""
is_stationary(agent, model) = notimplemented(model)

