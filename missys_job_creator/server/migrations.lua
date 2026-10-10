MJC = MJC or {}
MJC.Migrations = MJC.Migrations or {}

local M = MJC.Migrations

function M.legacyBossPoints()
    local key = 'legacy_boss_points_v2'
    local applied = MySQL.scalar.await('SELECT migration_key FROM missys_job_creator_migrations WHERE migration_key = ?', { key })
    if applied then return 0 end

    local jobs = MySQL.query.await('SELECT job_name, label, settings_json FROM missys_job_creator_jobs ORDER BY id') or {}
    local migrated = 0
    for i = 1, #jobs do
        local job = jobs[i]
        local settings = MJC.Validation.decode(job.settings_json, {})
        local boss = settings.boss
        if boss and boss.enabled and boss.x and boss.y and boss.z then
            local exists = tonumber(MySQL.scalar.await([[
                SELECT COUNT(*) FROM missys_job_creator_points
                WHERE job_name = ? AND point_type = 'boss'
                  AND ABS(x - ?) < 0.01 AND ABS(y - ?) < 0.01 AND ABS(z - ?) < 0.01
            ]], { job.job_name, tonumber(boss.x), tonumber(boss.y), tonumber(boss.z) })) or 0
            if exists == 0 then
                MySQL.insert.await([[
                    INSERT INTO missys_job_creator_points
                    (job_name, label, point_type, presentation_type, x, y, z, heading, radius, access_json, presentation_json, config_json, blip_json, hours_json, enabled)
                    VALUES (?, ?, 'boss', 'target', ?, ?, ?, ?, 2.0, ?, ?, ?, ?, ?, 1)
                ]], {
                    job.job_name,
                    (job.label or job.job_name) .. ' Boss Menu',
                    tonumber(boss.x), tonumber(boss.y), tonumber(boss.z), tonumber(boss.heading) or 0.0,
                    json.encode({ minGrade = 0, duty = 'any' }),
                    json.encode({}),
                    json.encode({ bossOnly = true }),
                    json.encode({}),
                    json.encode({ enabled = false }),
                })
                migrated = migrated + 1
            end
        end
    end

    MySQL.insert.await('INSERT IGNORE INTO missys_job_creator_migrations (migration_key) VALUES (?)', { key })
    return migrated
end
