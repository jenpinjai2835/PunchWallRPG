#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const clientPath = 'work/punch-wall-rpg/src/client/PunchWallClient.client.lua';
const baselineIndex = process.argv.indexOf('--baseline');
const baseline = baselineIndex < 0 ? null : process.argv[baselineIndex + 1] || '2fe4dea';
const old = baseline && spawnSync('git', ['show', `${baseline}:${clientPath}`], { cwd: root, encoding: 'utf8' });
if (old) assert.equal(old.status, 0, old.stderr);
const source = (old ? old.stdout : fs.readFileSync(path.join(root, clientPath), 'utf8')).replace(/\r\n?/g, '\n');
function block(start, end) {
  const from = source.indexOf(start), to = source.indexOf(end, from + start.length);
  assert.ok(from >= 0 && to > from, `Missing source boundary ${start}`);
  return source.slice(from, to);
}
const producer = block(source.includes('local settingsRuntime = {') ? 'local settingsRuntime = {' : 'renderStandaloneSettings = function()', '\ncloseStandaloneWindows = function(reason)');
const factories = block('local function setRounded(instance, radius)', '\nfunction legacyPetMenuRuntime.DeleteKey')
  + block('local function setDescendantZIndex(root, zIndex)', '\nlocal function shortReadyText');
const sound = block('shared.PunchWallApplySoundSetting = function(enabled, persist)', '\n\ndo\nlocal modalCoreGuiRuntime');
const tempRoot = os.tmpdir();
const candidates = [process.env.LUAU_COMMAND, ...fs.readdirSync(tempRoot).filter(name => name.startsWith('codex-luau-')).sort().reverse().map(name => path.join(tempRoot, name, process.platform === 'win32' ? 'luau.exe' : 'luau')), 'luau'];
const luau = candidates.find(candidate => candidate && spawnSync(candidate, ['--help'], { encoding: 'utf8' }).status === 0);
assert.ok(luau, 'BLOCKED: set LUAU_COMMAND to a Luau CLI executable');
const compiler = process.env.LUAU_COMPILE_COMMAND || path.join(path.dirname(luau), process.platform === 'win32' ? 'luau-compile.exe' : 'luau-compile');

const setup = `
local count=0
local function check(value,name) assert(value,name) count+=1 end
local function signal()
 local s={callbacks={}}
 function s:Connect(fn)
  local c={fn=fn,connected=true,Disconnect=function(self) self.connected=false end}
  table.insert(self.callbacks,c) return c
 end
 function s:Fire(...) for _,c in ipairs(table.clone(self.callbacks)) do if c.connected then c.fn(...) end end end
 function s:DisconnectAll() for _,c in ipairs(self.callbacks) do c:Disconnect() end end
 return s
end
local methods,objectMeta={},{}
objectMeta.__index=function(self,key) return methods[key] or self.props[key] end
objectMeta.__newindex=function(self,key,value)
 if key=='Parent' then
  local previous=self.props.Parent
  if previous then local i=table.find(previous.children,self) if i then table.remove(previous.children,i) end end
  self.props.Parent=value
  if value then table.insert(value.children,self) end
  self.AncestryChanged:Fire(self,value)
 else self.props[key]=value end
end
function methods:GetChildren() return table.clone(self.children) end
function methods:GetDescendants()
 local result={}
 for _,child in ipairs(self.children) do table.insert(result,child) for _,desc in ipairs(child:GetDescendants()) do table.insert(result,desc) end end
 return result
end
function methods:IsA(name)
 return self.ClassName==name or (name=='GuiObject' and table.find({'Frame','TextButton','TextLabel'},self.ClassName)~=nil)
  or (name=='UIComponent' and string.sub(self.ClassName,1,2)=='UI')
end
function methods:IsDescendantOf(root) local p=self.Parent while p do if p==root then return true end p=p.Parent end return false end
function methods:FindFirstChild(name,recursive)
 for _,child in ipairs(self.children) do if child.Name==name then return child end end
 if recursive then for _,child in ipairs(self.children) do local found=child:FindFirstChild(name,true) if found then return found end end end
 return nil
end
function methods:SetAttribute(name,value) self.attributes[name]=value end
function methods:GetAttribute(name) return self.attributes[name] end
function methods:Destroy()
 self.Destroying:Fire()
 for _,child in ipairs(self:GetChildren()) do child:Destroy() end
 self.Parent=nil self.Destroyed=true self.Activated:DisconnectAll()
end
local Instance={new=function(class)
 return setmetatable({props={ClassName=class,Name=class,Visible=true,Active=true,Selectable=true,ZIndex=1,Activated=signal(),Destroying=signal(),AncestryChanged=signal()},children={},attributes={}},objectMeta)
end}
local UDim={new=function(scale,offset) return {Scale=scale,Offset=offset} end}
local UDim2={new=function(xs,xo,ys,yo) return {X=UDim.new(xs,xo),Y=UDim.new(ys,yo)} end}
function UDim2.fromOffset(x,y) return UDim2.new(0,x,0,y) end
function UDim2.fromScale(x,y) return UDim2.new(x,0,y,0) end
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local Color3={fromRGB=function(r,g,b) return r..','..g..','..b end,new=function(r,g,b) return r..','..g..','..b end}
local Enum={Font={GothamBold='Bold',GothamBlack='Black'},TextXAlignment={Left='Left'},TextYAlignment={Center='Center'},
 FillDirection={Horizontal='Horizontal'},HorizontalAlignment={Right='Right'},VerticalAlignment={Center='Center'},UserInputType={Keyboard={Name='Keyboard'},Touch={Name='Touch'}}}
local palette={Reward='green',PanelSoft='gray',Text='white',MutedText='muted',Use='blue'}
local gui=Instance.new('ScreenGui')
local settingsPanel=Instance.new('Frame') settingsPanel.Parent=gui
local settingsBody=Instance.new('Frame') settingsBody.Parent=settingsPanel
local settingsSubtitle=Instance.new('TextLabel') settingsSubtitle.Parent=settingsPanel
local clientSettings={sound=true,motion=true,uiScale=1}
local requests,layoutCalls,closed,auras,honor={ },0,0,0,0
local actionRemote={FireServer=function(_,payload) table.insert(requests,{action=payload.action,value=table.clone(payload.value)}) end}
local deferred={}
local task={defer=function(fn) table.insert(deferred,fn) end}
local function flush() while #deferred>0 do local batch=deferred deferred={} for _,fn in ipairs(batch) do fn() end end end
local applyResponsiveLayout=function() layoutCalls+=1 end
local lastInput=Enum.UserInputType.Keyboard
local UserInputService={GetLastInputType=function() return lastInput end}
local selection
local GuiService=setmetatable({}, {__index=function(_,k) if k=='SelectedObject' then return selection end end,
 __newindex=function(_,k,v) if k=='SelectedObject' then assert(not v or not v.Destroyed,'deferred_focus_cannot_select_destroyed_control') selection=v end end})
local shared={PunchWallApplyFistAuraMotion=function() auras+=1 end,PunchWallRefreshHonorMotion=function() honor+=1 end}
local GameConfig={Audio={MusicVolume=.22}}
local backgroundMusic={IsPlaying=true,SoundId='music',Play=function(self) self.IsPlaying=true end}
${sound}
local function createThemeIcon(parent,_,position,size,name) local icon=Instance.new('Frame') icon.Name=name icon.Position=position icon.Size=size icon.Parent=parent return icon end
${factories}
local renderStandaloneSettings
local closeStandaloneWindows=function(reason) closed+=1 settingsPanel.Visible=false GuiService.SelectedObject=nil end
${producer}
local names={'SoundOn','SoundOff','MotionOn','MotionCalm','Scale80','Scale100','Scale120','Done'}
local function controls() local found={} for _,name in ipairs(names) do found[name]=settingsBody:FindFirstChild(name,true) end return found end
`;
const fixtures = {
  clockContinuity: `${setup}
renderStandaloneSettings() flush()
local original=controls()
local destroys=0
for _,button in pairs(original) do button.Destroying:Connect(function() destroys+=1 end) end
GuiService.SelectedObject=original.MotionCalm
local previousLayout=layoutCalls
for clock=1,12 do
 clientSettings={sound=true,motion=true,uiScale=1}
 renderStandaloneSettings() flush()
end
for _,name in ipairs(names) do check(controls()[name]==original[name] and original[name].Parent~=nil,'clock_snapshot_preserves_'..name) end
check(destroys==0 and #requests==0,'clock_snapshots_destroy_nothing_and_send_no_settings_requests')
check(GuiService.SelectedObject==original.MotionCalm,'clock_snapshots_preserve_current_focus')
check(layoutCalls==previousLayout,'unchanged_clock_snapshot_does_not_schedule_layout_work')
print('PASS '..count)
`,
  fiveSelections: `${setup}
renderStandaloneSettings() flush()
local original=controls()
local observed=0
for _,name in ipairs({'MotionCalm','MotionOn','SoundOff','SoundOn','Scale120'}) do
 original[name].Activated:Connect(function() check(original[name].Parent~=nil,'activated_observer_keeps_original_live_control') observed+=1 end)
end
for i,name in ipairs({'MotionCalm','MotionOn','SoundOff','SoundOn','Scale120'}) do
 GuiService.SelectedObject=original[name]
 local beforeLayout=layoutCalls
 original[name].Activated:Fire() flush()
 check(controls()[name]==original[name] and original[name].Parent~=nil,'setting_selection_preserves_activated_control')
 check(#requests==i and requests[i].action=='UpdateSettings','each_selection_sends_one_authoritative_request')
 check(GuiService.SelectedObject==original[name],'setting_selection_preserves_focus')
 check(layoutCalls-beforeLayout==(name=='Scale120' and 1 or 0),'only_scale_selection_schedules_one_responsive_layout')
end
check(observed==5 and #requests==5,'five_original_activated_observers_and_exact_requests_survive')
check(requests[1].value.motion==false and requests[2].value.motion==true and requests[3].value.sound==false and requests[4].value.sound==true and requests[5].value.uiScale==1.2,'five_request_values_remain_exact')
check(auras==2 and honor==2 and clientSettings.motion and clientSettings.sound,'motion_and_sound_side_effects_are_retained')
for _,name in ipairs(names) do check(controls()[name]==original[name],'all_setting_and_done_instances_survive_'..name) end
for _,name in ipairs({'SoundOn','MotionOn','Scale120'}) do check(original[name].BackgroundColor3==palette.Reward and original[name]:GetAttribute('SettingSelected')==true,'chosen_option_is_updated_in_place_'..name) end
for _,name in ipairs({'SoundOff','MotionCalm','Scale80','Scale100'}) do check(original[name].BackgroundColor3==palette.PanelSoft and original[name]:GetAttribute('SettingSelected')==false,'other_option_is_updated_in_place_'..name) end
for _,name in ipairs(names) do check(original[name].Size.Y.Offset>=44 and original[name]:GetAttribute('MinimumTouchTarget')==44,'minimum_touch_size_is_retained_'..name) end
check(original.MotionCalm.ZIndex==original.MotionCalm.Parent.ZIndex+1,'option_z_order_is_retained')
check(original.SoundOn.NextSelectionRight==original.SoundOff and original.SoundOff.NextSelectionLeft==original.SoundOn,'option_keyboard_navigation_is_retained')
print('PASS '..count)
`,
  lifecycle: `${setup}
renderStandaloneSettings()
local old=controls()
local oldCallback=old.MotionCalm.Activated.callbacks[1].fn
local oldDoneCallback=old.Done.Activated.callbacks[1].fn
old.MotionCalm:Destroy()
renderStandaloneSettings() flush()
local current=controls()
check(current.MotionCalm~=old.MotionCalm and current.SoundOn~=old.SoundOn,'invalid_control_lifetime_rebuilds_complete_valid_structure')
oldCallback()
check(#requests==0 and clientSettings.motion==true,'obsolete_callback_cannot_mutate_replacement_settings')
oldDoneCallback()
check(closed==0,'obsolete_done_cannot_close_replacement_panel')
check(GuiService.SelectedObject==current.SoundOn,'only_current_generation_receives_deferred_focus')
settingsPanel.Visible=false current.MotionCalm.Activated:Fire()
check(#requests==0,'hidden_panel_callback_is_ignored')
current.Done.Activated:Fire()
check(closed==0,'hidden_done_callback_is_ignored')
settingsPanel.Visible=true settingsPanel.Parent=Instance.new('Frame') current.MotionCalm.Activated:Fire()
check(#requests==0,'detached_panel_callback_is_ignored')
settingsPanel.Parent=gui renderStandaloneSettings(true) flush()
current.MotionCalm.Activated:Fire() flush()
check(#requests==1 and clientSettings.motion==false,'repaired_current_control_remains_usable')
local live=controls()
live.Done.Activated:Fire()
check(closed==1 and not settingsPanel.Visible and #requests==1,'done_closes_without_extra_settings_request')
settingsPanel.Visible=true renderStandaloneSettings(true) flush()
for _,name in ipairs(names) do check(controls()[name]==live[name],'close_reopen_preserves_'..name) end
print('PASS '..count)
`,
  authoritativeRefresh: `${setup}
renderStandaloneSettings() flush()
local original=controls()
GuiService.SelectedObject=original.Scale100
clientSettings={sound=false,motion=false,uiScale=.8}
local beforeLayout=layoutCalls
renderStandaloneSettings() flush()
check(controls().SoundOff==original.SoundOff and controls().Scale80==original.Scale80,'authoritative_value_update_preserves_control_identity')
check(original.SoundOff:GetAttribute('SettingSelected') and original.MotionCalm:GetAttribute('SettingSelected') and original.Scale80:GetAttribute('SettingSelected'),'authoritative_value_update_refreshes_selected_visuals')
check(settingsPanel:GetAttribute('SoundEnabled')==false and settingsPanel:GetAttribute('MotionEnabled')==false and settingsPanel:GetAttribute('UiScale')==.8,'panel_attributes_track_authoritative_values')
check(#requests==0 and GuiService.SelectedObject==original.Scale100,'authoritative_snapshot_neither_resends_nor_steals_focus')
check(layoutCalls-beforeLayout==1,'authoritative_scale_change_schedules_one_responsive_layout')
original.MotionOn.Activated:Fire()
check(#requests==1 and requests[1].value.motion==true and requests[1].value.sound==false and requests[1].value.uiScale==.8,'retained_callback_uses_current_settings_table_not_build_snapshot')
print('PASS '..count)
`,
};
const expectedFailures = {clockContinuity:'clock_snapshot_preserves_SoundOn',fiveSelections:'setting_selection_preserves_activated_control'};
const mutations = [
  {name:'disable_structure_reuse', fixture:'clockContinuity', from:'if settingsRuntime.ControlsCurrent() then', to:'if false then', expected:'clock_snapshot_preserves_SoundOn'},
  {name:'skip_reused_selection_refresh', fixture:'authoritativeRefresh', from:'\t\tsettingsRuntime.UpdateSelection()', to:'\t\t-- deliberately omit refresh', expected:'authoritative_value_update_refreshes_selected_visuals'},
  {name:'duplicate_authoritative_request', fixture:'fiveSelections', from:'\t\t\t\tonSelect(option.value)', to:'\t\t\t\tonSelect(option.value)\n\t\t\t\tonSelect(option.value)', expected:'each_selection_sends_one_authoritative_request'},
  {name:'accept_hidden_option', fixture:'lifecycle', from:'if generation ~= settingsRuntime.generation or not settingsPanel.Visible or settingsPanel.Parent ~= gui\n\t\t\t\t\tor button.Parent', to:'if generation ~= settingsRuntime.generation or settingsPanel.Parent ~= gui\n\t\t\t\t\tor button.Parent', expected:'hidden_panel_callback_is_ignored'},
  {name:'accept_detached_option', fixture:'lifecycle', from:'if generation ~= settingsRuntime.generation or not settingsPanel.Visible or settingsPanel.Parent ~= gui\n\t\t\t\t\tor button.Parent', to:'if generation ~= settingsRuntime.generation or not settingsPanel.Visible\n\t\t\t\t\tor button.Parent', expected:'detached_panel_callback_is_ignored'},
  {name:'accept_obsolete_option', fixture:'lifecycle', from:'if generation ~= settingsRuntime.generation or not settingsPanel.Visible or settingsPanel.Parent ~= gui\n\t\t\t\t\tor button.Parent ~= optionArea or optionArea.Parent ~= row or row.Parent ~= settingsBody\n\t\t\t\t\tor settingsBody.Parent ~= settingsPanel then return end', to:'-- deliberately omit option lifecycle guard', expected:'obsolete_callback_cannot_mutate_replacement_settings'},
  {name:'accept_obsolete_done', fixture:'lifecycle', from:'if generation ~= settingsRuntime.generation or not settingsPanel.Visible or settingsPanel.Parent ~= gui\n\t\t\tor done.Parent ~= footer or footer.Parent ~= settingsBody or settingsBody.Parent ~= settingsPanel then return end', to:'-- deliberately omit Done lifecycle guard', expected:'obsolete_done_cannot_close_replacement_panel'},
  {name:'omit_scale_layout', fixture:'fiveSelections', from:'if settingsRuntime.lastScale ~= clientSettings.uiScale then', to:'if false then', expected:'only_scale_selection_schedules_one_responsive_layout'},
  {name:'shrink_touch_target', fixture:'fiveSelections', from:'button.Size = UDim2.fromOffset(option.width or 78, 44)', to:'button.Size = UDim2.fromOffset(option.width or 78, 40)', expected:'minimum_touch_size_is_retained_SoundOn'},
  {name:'drop_option_z_order', fixture:'fiveSelections', from:'button.ZIndex = optionArea.ZIndex + 1', to:'button.ZIndex = optionArea.ZIndex', expected:'option_z_order_is_retained'},
  {name:'break_keyboard_navigation', fixture:'fiveSelections', from:'if previous then previous.NextSelectionRight = button button.NextSelectionLeft = previous end', to:'-- deliberately omit keyboard navigation', expected:'option_keyboard_navigation_is_retained'},
];
const temp=fs.mkdtempSync(path.join(tempRoot,'smash-settings-contract-'));
const files=[], results={}, compiled=[], rejectedMutations=[];
try {
  for (const [name,fixture] of Object.entries(fixtures)) {
    if (baseline && !(name in expectedFailures)) continue;
    const file=path.join(temp,`${name}.luau`);fs.writeFileSync(file,fixture);files.push(file);
    const run=spawnSync(luau,[file],{encoding:'utf8',timeout:15000});const output=`${run.stdout||''}${run.stderr||''}`;
    if(baseline){assert.ok(run.status!==0&&output.includes(expectedFailures[name]),`${name} wrong fail-before: ${output}`);results[name]={reproduced:expectedFailures[name]};}
    else{assert.equal(run.status,0,`${name}: ${output}`);results[name]={passed:Number(output.match(/PASS (\d+)/)?.[1]||0)};}
  }
  if(!baseline)for(const level of [0,1,2]){const run=spawnSync(compiler,['--null',`-O${level}`,path.join(root,clientPath)],{encoding:'utf8',timeout:15000});assert.equal(run.status,0,`BLOCKED O${level}: ${run.error||run.stderr||run.stdout}`);compiled.push(`O${level}`);}
  if(!baseline)for(const mutation of mutations){
    assert.equal(producer.split(mutation.from).length,2,`Mutation boundary must be unique: ${mutation.name}`);
    const altered=producer.replace(mutation.from,mutation.to);
    const file=path.join(temp,`mutation-${mutation.name}.luau`);files.push(file);
    fs.writeFileSync(file,fixtures[mutation.fixture].replace(producer,altered));
    const compile=spawnSync(compiler,['--null',file],{encoding:'utf8',timeout:15000});
    assert.equal(compile.status,0,`Mutation must remain valid Luau ${mutation.name}: ${compile.stderr}`);
    const run=spawnSync(luau,[file],{encoding:'utf8',timeout:15000});const output=`${run.stdout||''}${run.stderr||''}`;
    assert.ok(run.status!==0&&output.includes(mutation.expected),`Mutation survived or failed for wrong reason ${mutation.name}: ${output}`);
    rejectedMutations.push(mutation.name);
  }
  console.log(JSON.stringify({ok:true,source:baseline||'current',luau,results,compiled,rejectedMutations},null,2));
}finally{for(const file of files)fs.unlinkSync(file);fs.rmdirSync(temp);}
