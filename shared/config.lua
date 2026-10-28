Config = {}

Config.Command = 'craftCreator'

Config.Distance = 5.0

Config.Skills = {
    resource = 'kora_skills',
    getData = 'GetSkillsData', -- returns { skillName = 'Skill Label', ... }
    getRep = 'getRep',         -- (src, skill) -> { level, ... }
    isLevel = 'isLevel',       -- (src, skill, level) -> boolean
    addRep = 'addRep',         -- (src, skill, amount) -> true, or false and a reason
}
