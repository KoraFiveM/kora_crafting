Config = {}

-- Chat command that opens the creator. Needs the "command" ace, like /drugCreator.
Config.Command = 'craftCreator'

-- How close (in metres) a player has to be to a station location to use it.
Config.Distance = 5.0

-- The skills resource and the exports this script calls (see server/skills.lua).
Config.Skills = {
    resource = 'qbskills',
    getData = 'GetSkillsData', -- returns { skillName = 'Skill Label', ... }
    getRep = 'getRep',         -- (src, skill) -> { level, ... }
    isLevel = 'isLevel',       -- (src, skill, level) -> boolean
    addRep = 'addRep',         -- (src, skill, amount) -> true, or false and a reason
}
