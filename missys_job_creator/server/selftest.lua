MJC = MJC or {}
MJC.SelfTest = {}

function MJC.SelfTest.run()
    local results = {}
    local function check(name, condition, detail)
        results[#results + 1] = { name = name, pass = condition == true, detail = detail }
    end

    -- Core resources and v2 modules. These checks are read-only.
    check('qbx_core started', GetResourceState('qbx_core') == 'started', GetResourceState('qbx_core'))
    check('ox_inventory started', GetResourceState('ox_inventory') == 'started', GetResourceState('ox_inventory'))
    check('ox_target started', GetResourceState('ox_target') == 'started', GetResourceState('ox_target'))
    check('oxmysql started', GetResourceState('oxmysql') == 'started', GetResourceState('oxmysql'))
    check('qbx_management optional', GetResourceState('qbx_management') == 'started', GetResourceState('qbx_management'))
    check('lation_banking optional', GetResourceState('lation_banking') == 'started', GetResourceState('lation_banking'))

    check('permissions module', type(MJC.Permissions) == 'table' and type(MJC.Permissions.isAdmin) == 'function', nil)
    check('state loaded', type(MJC.State) == 'table' and type(MJC.State.jobs) == 'table' and type(MJC.State.points) == 'table', nil)
    check('points module', type(MJC.Points) == 'table' and type(MJC.Points.canUse) == 'function', nil)
    check('point actions module', type(MJC.PointActions) == 'table' and type(MJC.PointActions.use) == 'function', nil)
    check('blips module', type(MJC.Blips) == 'table' and type(MJC.Blips.save) == 'function', nil)
    check('fleet module', type(MJC.Fleet) == 'table' and type(MJC.Fleet.requestLease) == 'function', nil)
    check('integrations module', type(MJC.Integrations) == 'table' and type(MJC.Integrations.status) == 'function', nil)

    local qbxReady = GetResourceState('qbx_core') == 'started'
    if qbxReady then
        for _, job in pairs(MJC.State.jobs or {}) do
            check(('job %s has grade 0'):format(job.job_name), job.grades[1] and tonumber(job.grades[1].grade_level) == 0, nil)
            if MJC.Validation.isEnabled(job.enabled) then
                check(('job %s exists in QBX'):format(job.job_name), exports.qbx_core:GetJob(job.job_name) ~= nil, nil)
            end
        end
        for _, business in pairs(MJC.State.businesses or {}) do
            check(('business %s job exists'):format(business.label), exports.qbx_core:GetJob(business.job_name) ~= nil, business.job_name)
        end
    end

    for _, shop in pairs(MJC.State.shops or {}) do
        check(('shop %s has NPC'):format(shop.id), MJC.State.npcs and MJC.State.npcs[tonumber(shop.npc_id)] ~= nil, nil)
        if shop.stock_mode == 'business' then
            check(('shop %s has business'):format(shop.id), MJC.Persistence.findBusinessByJob(shop.business_job) ~= nil, shop.business_job)
        end
    end

    for _, point in pairs(MJC.State.points or {}) do
        check(('point %s action valid'):format(point.id), MJC.PointTypes.isAction(point.point_type), point.point_type)
        check(('point %s presentation valid'):format(point.id), MJC.PointTypes.isPresentation(point.presentation_type), point.presentation_type)
    end

    local passed = 0
    for i = 1, #results do if results[i].pass then passed = passed + 1 end end
    return { total = #results, passed = passed, failed = #results - passed, results = results }
end

RegisterCommand(Config.SelfTestCommand or 'jobcreatortest', function(source)
    if not MJC.Permissions.requireAdmin(source) then return end
    local report = MJC.SelfTest.run()
    local summary = ('[missys_job_creator] self-test %s: %s assertions, %s failures'):format(report.failed == 0 and 'PASS' or 'FAIL', report.total, report.failed)
    print(summary)
    for i = 1, #report.results do
        local row = report.results[i]
        print(('  [%s] %s%s'):format(row.pass and 'PASS' or 'FAIL', row.name, row.detail and (' (' .. tostring(row.detail) .. ')') or ''))
    end
    if source > 0 and GetResourceState('qbx_core') == 'started' then
        exports.qbx_core:Notify(source, summary, report.failed == 0 and 'success' or 'error', 7000)
    end
end, false)
