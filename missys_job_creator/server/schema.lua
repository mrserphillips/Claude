MJC = MJC or {}
MJC.Schema = {}

function MJC.Schema.ensure()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/missys_job_creator.sql')
    if not sql then error('Could not load sql/missys_job_creator.sql') end
    local statements = {}
    for statement in sql:gmatch('([^;]+);') do
        statement = statement:match('^%s*(.-)%s*$')
        if statement and statement ~= '' then statements[#statements + 1] = statement end
    end
    for i = 1, #statements do MySQL.query.await(statements[i]) end
    if MJC.Migrations and MJC.Migrations.legacyBossPoints then
        local migrated = MJC.Migrations.legacyBossPoints()
        if migrated > 0 then
            print(('[missys_job_creator] Migrated %s legacy boss point(s) into v2 world points.'):format(migrated))
        end
    end
    return #statements
end
