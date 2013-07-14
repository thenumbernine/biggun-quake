$cd id1/models/shams
$origin 0 0 24
$base base		
$skin base

$frame stand1 stand2 stand3 stand4 stand5 stand6 stand7 stand8 stand9
$frame stand10 stand11 stand12 stand13 stand14 stand15 stand16 stand17

$frame walk1 walk2 walk3 walk4 walk5 walk6 walk7 
$frame walk8 walk9 walk10 walk11 walk12

$frame	run1 run2 run3 run4 run5 run6

$frame smash1 smash2 smash3 smash4 smash5 smash6 smash7 
$frame smash8 smash9 smash10 smash11 smash12

$frame swingr1 swingr2 swingr3 swingr4 swingr5 
$frame swingr6 swingr7 swingr8 swingr9

$frame swingl1 swingl2 swingl3 swingl4 swingl5 
$frame swingl6 swingl7 swingl8 swingl9

$frame magic1 magic2 magic3 magic4 magic5 
$frame magic6 magic7 magic8 magic9 magic10 magic11 magic12

$frame pain1 pain2 pain3 pain4 pain5 pain6

$frame death1 death2 death3 death4 death5 death6 
$frame death7 death8 death9 death10 death11

void() smite_checklife =
{
	if (time > self.next_attack_time) self.th_die();
};

void() smite_stand1      =[      $stand1,	smite_stand2     ] {ai_stand();smite_checklife();};
void() smite_stand2      =[      $stand2,	smite_stand3     ] {ai_stand();};
void() smite_stand3      =[      $stand3,	smite_stand4     ] {ai_stand();};
void() smite_stand4      =[      $stand4,	smite_stand5     ] {ai_stand();};
void() smite_stand5      =[      $stand5,	smite_stand6     ] {ai_stand();};
void() smite_stand6      =[      $stand6,	smite_stand7     ] {ai_stand();};
void() smite_stand7      =[      $stand7,	smite_stand8     ] {ai_stand();};
void() smite_stand8      =[      $stand8,	smite_stand9     ] {ai_stand();};
void() smite_stand9      =[      $stand9,	smite_stand10] {ai_stand();};
void() smite_stand10     =[      $stand10,	smite_stand11] {ai_stand();};
void() smite_stand11     =[      $stand11,	smite_stand12] {ai_stand();};
void() smite_stand12     =[      $stand12,	smite_stand13] {ai_stand();};
void() smite_stand13     =[      $stand13,	smite_stand14] {ai_stand();};
void() smite_stand14     =[      $stand14,	smite_stand15] {ai_stand();};
void() smite_stand15     =[      $stand15,	smite_stand16] {ai_stand();};
void() smite_stand16     =[      $stand16,	smite_stand17] {ai_stand();};
void() smite_stand17     =[      $stand17,	smite_stand1	] {ai_stand();};

void() smite_walk1	       =[      $walk1,	smite_walk2 ] {ai_walk(7);smite_checklife();};
void() smite_walk2       =[      $walk2,	smite_walk3 ] {ai_walk(7);};
void() smite_walk3       =[      $walk3,	smite_walk4 ] {ai_walk(7);};
void() smite_walk4       =[      $walk4,	smite_walk5 ] {ai_walk(2);};
void() smite_walk5       =[      $walk5,	smite_walk6 ] {ai_walk(3);};
void() smite_walk6       =[      $walk6,	smite_walk7 ] {ai_walk(8);};
void() smite_walk7       =[      $walk7,	smite_walk8 ] {ai_walk(5);};
void() smite_walk8       =[      $walk8,	smite_walk9 ] {ai_walk(1);};
void() smite_walk9       =[      $walk9,	smite_walk10] {ai_walk(9);};
void() smite_walk10      =[      $walk10,       smite_walk11] {ai_walk(6);};
void() smite_walk11      =[      $walk11,       smite_walk12] {ai_walk(4);};
void() smite_walk12      =[      $walk12,       smite_walk1 ] {ai_walk(4);
if (random() > 0.8)
	sound (self, CHAN_VOICE, "shambler/sidle.wav", 1, ATTN_IDLE);};

void() smite_run1       =[      $run1,	smite_run2      ] {ai_run(40);smite_checklife();};
void() smite_run2       =[      $run2,	smite_run3      ] {ai_run(44);};
void() smite_run3       =[      $run3,	smite_run4      ] {ai_run(40);};
void() smite_run4       =[      $run4,	smite_run5      ] {ai_run(40);};
void() smite_run5       =[      $run5,	smite_run6      ] {ai_run(44);};
void() smite_run6       =[      $run6,	smite_run1      ] {ai_run(40);
if (random() > 0.8)
	sound (self, CHAN_VOICE, "shambler/sidle.wav", 1, ATTN_IDLE);
};

void() smite_smash1     =[      $smash1,       smite_smash10    ] {sound (self, CHAN_VOICE, "shambler/melee1.wav", 1, ATTN_NORM);ai_charge(2);};
void() smite_smash10    =[      $smash10,      smite_run1   ] {
local vector	delta;
local float 	ldmg;

	if (!self.enemy)
		return;
	ai_charge(0);

	delta = self.enemy.origin - self.origin;

	if (vlen(delta) > 100)
		return;
	if (!CanDamage (self.enemy, self))
		return;
		
	//t_damage_kill = 1;
	//T_Damage (self.enemy, self, self, 50000);
	bring_on_the_smite(self.enemy);

	sound (self, CHAN_VOICE, "shambler/smack.wav", 1, ATTN_NORM);

	SpawnMeatSpray (self.origin + v_forward*16, crandom() * 100 * v_right);
	SpawnMeatSpray (self.origin + v_forward*16, crandom() * 100 * v_right);
};

void(float side) Smite_Claw =
{
local vector	delta;
local float 	ldmg;

	if (!self.enemy)
		return;
	ai_charge(10);

	delta = self.enemy.origin - self.origin;

	if (vlen(delta) > 100)
		return;
		
	//T_Damage (self.enemy, self, self, 100);
	bring_on_the_smite(self.enemy);

	sound (self, CHAN_VOICE, "shambler/smack.wav", 1, ATTN_NORM);

	if (side) {
		makevectors (self.angles);
		SpawnMeatSpray (self.origin + v_forward*16, side * v_right);
	}
};

void() smite_swing =
{
	local float snd;

	snd = random();

	if (snd < 0.1)      sound (self, CHAN_VOICE, "shambler/melee2.wav", 1, ATTN_NORM);
	else if (snd < 0.2) sound (self, CHAN_VOICE, "shambler/melee1.wav", 1, ATTN_NORM);

	ai_charge(5);

	self.frame = $swingr1 + random() * 10;

	Smite_Claw(250 * crandom());

	if (random() < 0.4)     self.think = smite_swing;
	else		    self.think = smite_run1;

	self.nextthink = time + 0.1;
};

void() smite_melee =
{
	local float chance;
	
	chance = random();
	if (chance > 0.6)
		smite_smash1 ();
	else
		smite_swing ();
};


//============================================================================

void() smite_die =
{
	spawn_tfog(self.origin);
	remove(self);
};


void(entity smitten) bring_on_the_smite =
{
	local entity    smite;

	smite = spawn();

	smite.classname = "monster_smite";

	setorigin(smite, smitten.origin);
	smite.angles = smitten.angles;

	smite.solid = SOLID_SLIDEBOX;
	smite.movetype = MOVETYPE_STEP;
	setmodel (smite, "progs/shambler.mdl");

	setsize (smite, VEC_HULL_MIN, VEC_HULL_MAX);
	smite.next_attack_time = time + 30;       //seconds of fun!

	sound (self, CHAN_AUTO, "boss1/sight1.wav", 1, ATTN_NORM);

	smite.health = 1;
	smite.flags = smite.flags | FL_GODMODE;

	smite.th_stand = smite_stand1;
	smite.th_walk = smite_walk1;
	smite.th_run = smite_run1;
	smite.th_melee = smite_melee;
	smite.th_pain = smite_run1;
	smite.th_die = smite_die;

	smite.takedamage = DAMAGE_AIM;

	smite.ideal_yaw = smite.angles * '0 1 0';
	if (!smite.yaw_speed) smite.yaw_speed = 20;
	smite.view_ofs = '0 0 25';

	smite.use = monster_use;
	
	smite.flags = smite.flags | FL_FLY;
	smite.flags = smite.flags | FL_MONSTER;

	smite.think = smite.th_stand;
	smite.nextthink = time + 0.1;

	if (smitten.takedamage) {
		t_damage_kill = 1;
		T_Damage(smitten, smite, smite, 50001);
	}
};
