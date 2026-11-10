KoraCraftingSchema = {
    {
        name = 'kora_crafting_recipes',
        columns = {
            { name = 'id', type = 'varchar(48)' },
            { name = 'data', type = 'longtext' },
        },
        primary = { 'id' },
    },
    {
        name = 'kora_crafting_stations',
        columns = {
            { name = 'id', type = 'varchar(48)' },
            { name = 'data', type = 'longtext' },
            { name = 'locations', type = 'longtext' },
        },
        primary = { 'id' },
    },
    {
        name = 'kora_crafting_logs',
        columns = {
            { name = 'id', type = 'int', auto_increment = true },
            { name = 'created_at', type = 'timestamp', default = { raw = 'CURRENT_TIMESTAMP' } },
            { name = 'source', type = 'int' },
            { name = 'name', type = 'varchar(64)' },
            { name = 'identifier', type = 'varchar(64)' },
            { name = 'action', type = 'varchar(64)' },
            { name = 'details', type = 'text' },
        },
        primary = { 'id' },
        indexes = { { name = 'created_at', columns = { 'created_at' } } },
    },
}
