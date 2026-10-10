MJC=MJC or {}; MJC.Integrations=MJC.Integrations or {}
local I=MJC.Integrations

local definitions={
    {resource='qbx_core',required=true,adapter='QBX',feature='Jobs, duty, player money and group access'},
    {resource='ox_lib',required=true,adapter='ox_lib',feature='Callbacks, contexts, input and progress UI'},
    {resource='ox_inventory',required=true,adapter='ox_inventory',feature='Stashes, stock, crafting and item actions'},
    {resource='ox_target',required=true,adapter='ox_target',feature='NPC, prop and target point interactions'},
    {resource='oxmysql',required=true,adapter='oxmysql',feature='Persistent creator data'},
    {resource='qbx_management',required=false,adapter='QBX management',feature='Boss menu world points'},
    {resource='lation_banking',required=false,adapter='Lation Banking',feature='Business society revenue'},
    {resource='illenium-appearance',required=false,adapter='Illenium Appearance',feature='Wardrobe and job outfits'},
    {resource='fivem-appearance',required=false,adapter='FiveM Appearance',feature='Wardrobe fallback'},
}

function I.status()
    local result={}
    for _,row in ipairs(definitions) do
        local state=GetResourceState(row.resource)
        result[#result+1]={resource=row.resource,required=row.required,adapter=row.adapter,feature=row.feature,state=state,running=state=='started' or state=='starting'}
    end
    local appearance='none'
    if GetResourceState('illenium-appearance')=='started' then appearance='illenium-appearance'
    elseif GetResourceState('fivem-appearance')=='started' then appearance='fivem-appearance' end
    result[#result+1]={resource='appearance-adapter',required=false,adapter=appearance,feature='Selected clothing adapter',state=appearance=='none' and 'missing' or 'started',running=appearance~='none'}
    return result
end
