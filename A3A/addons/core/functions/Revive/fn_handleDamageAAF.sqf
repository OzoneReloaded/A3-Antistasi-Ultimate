// HandleDamage event handler for enemy (gov/inv) AIs
params ["_unit","_part","_damage","_injurer","_projectile","_hitIndex","_instigator","_hitPoint", ["_unconsciousChance", 15]];

// Functionality unrelated to Antistasi revive
if (side group _injurer == teamPlayer) then
{
	private _randomNumber = [1,100] call BIS_fnc_randomNum;
	// Helmet popping: use _hitpoint rather than _part to work around ACE calling its fake hitpoint "head"
	if (_damage >= 1 && {_hitPoint == "hithead"} && {helmetLossChance >= _randomNumber}) then
	{
		if (headgear _unit isNotEqualTo "") then 
		{
			if (headgear _unit isNotEqualTo "" && {_unit getVariable ["A3U_hasHelmetPopped", false] isEqualTo false}) then 
			{
				_unit setVariable ["A3U_hasHelmetPopped", true, true];
				removeHeadgear _unit;
				if (helmetLossSound) then 
				{
					[_unit, ["HelmetLoss", 150, 1, 0, 0]] remoteExec ["say3D", 0];
				};
			};
		};
	};

	private _groupX = group _unit;
	if (time > _groupX getVariable ["movedToCover",0]) then
	{
		if ((behaviour leader _groupX != "COMBAT") and (behaviour leader _groupX != "STEALTH")) then
		{
			_groupX setVariable ["movedToCover",time + 120];
			{[_x,_injurer] spawn A3A_fnc_unitGetToCover} forEach units _groupX;
		};
	};

	if (_part == "" && _damage < 1) then 
	{
		if (_damage > 0.6) then {[_unit,_injurer] spawn A3A_fnc_unitGetToCover};
	};

	// Contact report generation for PvP players
	if (_part == "" && side group _unit == Occupants) then
	{
		private _marker = _unit getVariable ["markerX",""];
		if (_marker != "" && {sidesX getVariable [_marker,sideUnknown] == Occupants}) then
		{
			private _lastAttackTime = garrison getVariable [_marker + "_lastAttack", -30];
			if (_lastAttackTime + 30 < serverTime) then {
				garrison setVariable [_marker + "_lastAttack", serverTime, true];
				[_marker, teamPlayer, side group _unit, false, (_injurer getVariable ["isRival", false])] remoteExec ["A3A_fnc_underAttack", 2];
			};
		};
	};
};

// Let ACE medical handle the rest
if (A3A_hasACEMedical) exitWith {};

// Helper function to make unconscious
private _makeUnconscious =
{
	params ["_unit", "_injurer"];
	_unit setVariable ["incapacitated",true,true];
	_unit setVariable ["helpFailed", 0];
	_unit setUnconscious true;
	if (vehicle _unit != _unit) then { moveOut _unit };
	if (isPlayer _unit) then { _unit allowDamage false };
	if (_unit == leader (group _unit)) then
	{
		private _index = (units (group _unit)) findIf {[_x] call A3A_fnc_canFight};
		if(_index != -1) then {
			(group _unit) selectLeader ((units (group _unit)) select _index);
		};
	};
	[_unit, group _unit, _injurer] spawn A3A_fnc_AIreactOnKill;
	[_unit,_injurer] spawn A3A_fnc_unconsciousAAF;
};

// Unconscious chance logic
private _roll = random 100;
private _allowUnconscious = (_roll < _unconsciousChance);

if (side _injurer == teamPlayer) then
{
	if (_part == "") then
	{
		if (_damage >= 1) then
		{
			if (!(_unit getVariable ["incapacitated",false]) && {_unit getVariable ["canBeIncapacitated",true]} && {_allowUnconscious}) then
			{
				_damage = 0.9;
				[_unit,_injurer] call _makeUnconscious;
			}
			else
			{
				private _overall = (_unit getVariable ["overallDamage",0]) + (_damage - 1);
				if (_overall > 0.5) then
				{
					_unit removeAllEventHandlers "HandleDamage";
				}
				else
				{
					_unit setVariable ["overallDamage",_overall];
					_damage = 0.9;
				};
			};
		}
		else
		{
			if (_damage > 0.25) then
			{
				if (_unit getVariable ["helping",false]) then
				{
					_unit setVariable ["cancelRevive",true];
				};
			};
		};
	}
	else
	{
		if (_damage >= 1) then
		{
			if !(_part in ["arms","hands","legs"]) then
			{
				_damage = 0.9;
				if (_part in ["head","body"]) then
				{
					if (!(_unit getVariable ["incapacitated",false]) && {_unit getVariable ["canBeIncapacitated",true]} && {_allowUnconscious}) then
					{
						[_unit,_injurer] call _makeUnconscious;
					};
				};
			};
		};
	};
};

_damage
