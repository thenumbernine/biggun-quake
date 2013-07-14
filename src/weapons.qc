/*
*/
void (entity targ, entity inflictor, entity attacker, float damage) T_Damage;
void () player_run;
void(entity bomb, entity attacker, float rad, entity ignore) T_RadiusDamage;
void(vector org, vector vel, float damage) SpawnBlood;
void() SuperDamageSound;

float() W_BestWeapon;


// called by worldspawn
void() W_Precache = {

	precache_sound ("weapons/r_exp3.wav");	// new rocket explosion
	precache_sound ("weapons/rocket1i.wav");	// spike gun
	precache_sound ("weapons/sgun1.wav");
	precache_sound ("weapons/guncock.wav");	// player shotgun
	precache_sound ("weapons/ric1.wav");	// ricochet (used in c code)
	precache_sound ("weapons/ric2.wav");	// ricochet (used in c code)
	precache_sound ("weapons/ric3.wav");	// ricochet (used in c code)
	precache_sound ("weapons/spike2.wav");	// super spikes
	precache_sound ("weapons/tink1.wav");	// spikes tink (used in c code)
	precache_sound ("weapons/grenade.wav");	// grenade launcher
	precache_sound ("weapons/bounce.wav");		// grenade bounce
	precache_sound ("weapons/shotgn2.wav");	// super shotgun

	precache_sound ("shambler/smack.wav");
	precache_sound ("blob/land1.wav");
	precache_model2 ("progs/k_spike.mdl");  //for the fat gun
};

float() crandom = {
	return 2*(random() - 0.5);
};

vector() vcrandom =
{
	local vector v;
	v_x = crandom();
	v_y = crandom();
	v_z = crandom();
	return v;
};

void(vector ang) Biggun_Aim = {
	local vector del;

	if ((self.rune_autoaim_count > 0) &&
		(self.hsa != world) &&
		(self.hsa.enemy != world) &&
		(random() <= self.rune_autoaim_count / (self.rune_autoaim_count + 3)))
	{
		del = (self.hsa.enemy.absmax + self.hsa.enemy.absmin) * 0.5 - self.origin;
		del_z = 0 - del_z;
		del = vectoangles(del);

		makevectors(del);
	} else {
		makevectors(ang);
		if (self.rune_burst_count) {
			v_forward = v_forward + vcrandom() * 0.02;
			v_up = v_up + vcrandom() * 0.02;
			v_right = v_right + vcrandom() * 0.02;
		}
	}
};

/*
================
W_FireAxe
================
*/
void() W_FireAxe =
{
	local	vector	source;
	local	vector	org;

	Biggun_Aim (self.v_angle);
	source = self.origin + '0 0 16';
	traceline (source, source + v_forward*64, FALSE, self);
	if (trace_fraction == 1.0)
		return;
	
	org = trace_endpos - v_forward*4;

	if (trace_ent.takedamage)
	{
		trace_ent.axhitme = 1;
		SpawnBlood (org, '0 0 0', 20);
		T_Damage (trace_ent, self, self, 20);
	}
	else
	{	// hit wall
		sound (self, CHAN_WEAPON, "player/axhit2.wav", 1, ATTN_NORM);
		WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
		WriteByte (MSG_BROADCAST, TE_GUNSHOT);
		WriteCoord (MSG_BROADCAST, org_x);
		WriteCoord (MSG_BROADCAST, org_y);
		WriteCoord (MSG_BROADCAST, org_z);
	}
};


//============================================================================


vector() wall_velocity =
{
	local vector	vel;
	
	vel = normalize (self.velocity);
	vel = normalize(vel + v_up*(random()- 0.5) + v_right*(random()- 0.5));
	vel = vel + 2*trace_plane_normal;
	vel = vel * 200;
	
	return vel;
};


/*
================
SpawnMeatSpray
================
*/
void(vector org, vector vel) SpawnMeatSpray = {
	local	entity missile, mpuff;
	local	vector	org;

	missile = spawn ();
	missile.owner = self;
	missile.movetype = MOVETYPE_BOUNCE;
	missile.solid = SOLID_NOT;

	makevectors (self.angles);

	missile.velocity = vel;
	missile.velocity_z = missile.velocity_z + 250 + 50*random();

	missile.avelocity = '3000 1000 2000';
	
// set missile duration
	missile.nextthink = time + 1;
	missile.think = SUB_Remove;

	setmodel (missile, "progs/zom_gib.mdl");
	setsize (missile, '0 0 0', '0 0 0');		
	setorigin (missile, org);
};

/*
================
SpawnBlood
================
*/
void(vector org, vector vel, float damage) SpawnBlood =
{
	particle (org, vel*0.1, 73, damage*2);
};

/*
================
spawn_touchblood
================
*/
void(float damage) spawn_touchblood =
{
	local vector	vel;

	vel = wall_velocity () * 0.2;
	SpawnBlood (self.origin + vel*0.01, vel, damage);
};


/*
================
SpawnChunk
================
*/
void(vector org, vector vel) SpawnChunk =
{
	particle (org, vel*0.02, 0, 10);
};

/*
==============================================================================

MULTI-DAMAGE

Collects multiple small damages into a single damage

==============================================================================
*/

entity	multi_ent;
float	multi_damage;

float   do_a_goreshaft;

void() ClearMultiDamage =
{
	multi_ent = world;
	multi_damage = 0;
};

void() ApplyMultiDamage =
{
	if (!multi_ent)
		return;
	t_damage_type = AT_BULLETS;
	T_Damage (multi_ent, self, self, multi_damage);


//from here on down is my goreshaft mod

	if (!do_a_goreshaft) return;

	if (multi_ent.takedamage == DAMAGE_NO) return;

	if ((multi_ent.takedamage == DAMAGE_YES) || (multi_ent.movetype == MOVETYPE_NONE)) {
		t_damage_type = AT_BULLETS;
		T_Damage(multi_ent, self, self, 1000);
		return;
	}

	if (multi_ent.health <= 0) return;

	//so now only living DAMAGE_AIM remains...

	if ((teamplay != 1) || (multi_ent.team != self.team)) {
		if (!self.rune_burst_count) {
			multi_ent.health = ceil(multi_ent.health * 0.5);
			if (multi_ent.health < 1) multi_ent.health = 1;
			multi_ent.my_flags = multi_ent.my_flags | MY_GORED;
		} else {
			//for the gore shaft - if we have burst runes - then insta kill
			t_damage_kill = 1;
			T_Damage(multi_ent, self, self, 50000);
		}
	}

};

void(entity hit, float damage) AddMultiDamage =
{
	if (!hit)
		return;
	
	if (hit != multi_ent)
	{
		ApplyMultiDamage ();
		multi_damage = damage;
		multi_ent = hit;
	}
	else
		multi_damage = multi_damage + damage;
};

/*
==============================================================================

BULLETS

==============================================================================
*/

/*
================
TraceAttack
================
*/
void(float damage, vector dir) TraceAttack =
{
	local	vector	vel, org;
	
	vel = normalize(dir + v_up*crandom() + v_right*crandom());
	vel = vel + 2*trace_plane_normal;
	vel = vel * 200;

	org = trace_endpos - dir*4;

	if (trace_ent.takedamage)
	{
		SpawnBlood (org, vel*0.2, damage);
		AddMultiDamage (trace_ent, damage);
	}
	else
	{
		WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
		WriteByte (MSG_BROADCAST, TE_GUNSHOT);
		WriteCoord (MSG_BROADCAST, org_x);
		WriteCoord (MSG_BROADCAST, org_y);
		WriteCoord (MSG_BROADCAST, org_z);
	}
};

/*
================
FireBullets

Used by shotgun, super shotgun, and enemy soldier firing
Go to the trouble of combining multiple pellets into a single damage call.
================
*/
void(float shotcount, vector dir, vector spread) FireBullets =
{
	local	vector direction;
	local	vector	src;
	
	Biggun_Aim(self.v_angle);

	src = self.origin + v_forward*10;
	src_z = self.absmin_z + self.size_z * 0.7;

	ClearMultiDamage ();
	while (shotcount > 0)
	{
		direction = dir + crandom()*spread_x*v_right + crandom()*spread_y*v_up;

		traceline (src, src + direction*2048, FALSE, self);
		if (trace_fraction != 1.0)
			TraceAttack (4, direction);

		shotcount = shotcount - 1;
	}
	ApplyMultiDamage ();
};


/*
================
W_FireShotgun
================
*/
void() W_FireShotgun =
{
	local vector dir;

	sound (self, CHAN_WEAPON, "weapons/guncock.wav", 1, ATTN_NORM);	

	self.punchangle_x = -2;
	
//	self.currentammo = self.ammo_shells = self.ammo_shells - 1;
	dir = aim (self, 100000);
	FireBullets (6, dir, '0.04 0.04 0');
};


/*
================
W_FireSuperShotgun
================
*/
void() W_FireSuperShotgun =
{
	local vector dir;

	sound (self ,CHAN_WEAPON, "weapons/shotgn2.wav", 1, ATTN_NORM);	

	self.punchangle_x = -4;
	
	dir = aim (self, 100000);
	FireBullets (14, dir, '0.14 0.08 0');
};


/*
==============================================================================

ROCKETS

==============================================================================
*/

void()	s_explode1	=	[0,		s_explode2] {};
void()	s_explode2	=	[1,		s_explode3] {};
void()	s_explode3	=	[2,		s_explode4] {};
void()	s_explode4	=	[3,		s_explode5] {};
void()	s_explode5	=	[4,		s_explode6] {};
void()	s_explode6	=	[5,		SUB_Remove] {};

void() BecomeExplosion =
{
	self.movetype = MOVETYPE_NONE;
	self.velocity = '0 0 0';
	self.touch = SUB_Null;
	setmodel (self, "progs/s_explod.spr");
	self.solid = SOLID_NOT;
	s_explode1 ();
};

void() T_MissileTouch =
{
	local float	damg;
        local vector    neworg;

	if (other == self.owner)
		return;		// don't explode on owner

	if (pointcontents(self.origin) == CONTENT_SKY)
	{
		remove(self);
		return;
	}

	damg = 100 + random()*20;
	
	if (other.health)
	{
		if (other.classname == "monster_shambler")
			damg = damg * 0.5;	// mostly immune
		t_damage_type = AT_EXPLOSION;
		T_Damage (other, self, self.owner, damg );
	}

	// don't do radius damage to the other, because all the damage
	// was done in the impact
	t_damage_type = AT_EXPLOSION;
	T_RadiusDamage (self, self.owner, 120, other);

//	sound (self, CHAN_WEAPON, "weapons/r_exp3.wav", 1, ATTN_NORM);
        neworg = normalize(self.velocity);
        neworg = self.origin - 8 * neworg;
        setorigin(self, neworg);

	WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
	WriteByte (MSG_BROADCAST, TE_EXPLOSION);
	WriteCoord (MSG_BROADCAST, self.origin_x);
	WriteCoord (MSG_BROADCAST, self.origin_y);
	WriteCoord (MSG_BROADCAST, self.origin_z);

	BecomeExplosion ();
};



/*
================
W_FireRocket
================
*/
void() W_FireRocket =
{
	local	entity missile, mpuff;
	
	sound (self, CHAN_WEAPON, "weapons/sgun1.wav", 1, ATTN_NORM);

	self.punchangle_x = -2;

	missile = spawn ();
	missile.owner = self;
	missile.movetype = MOVETYPE_FLYMISSILE;
	missile.solid = SOLID_BBOX;
	missile.classname = "missile";
		
// set missile speed	

	Biggun_Aim (self.v_angle);
	missile.velocity = v_forward * 1000;
	missile.angles = vectoangles(missile.velocity);
	
	missile.touch = T_MissileTouch;
	
// set missile duration
	missile.nextthink = time + 5;
	missile.think = SUB_Remove;

	setmodel (missile, "progs/missile.mdl");
	setsize (missile, '0 0 0', '0 0 0');		
	setorigin (missile, self.origin + v_forward*8 + '0 0 16');
};

/*
===============================================================================

LIGHTNING

===============================================================================
*/

/*
=================
LightningDamage
=================
*/
void(vector p1, vector p2, entity from, float damage) LightningDamage =
{
	local entity		e1, e2;
	local vector		f;
	
	f = p2 - p1;
	normalize (f);
	f_x = 0 - f_y;
	f_y = f_x;
	f_z = 0;
	f = f*16;

	e1 = e2 = world;

	traceline (p1, p2, FALSE, self);
	if (trace_ent.takedamage)
	{
		particle (trace_endpos, '0 0 100', 225, damage*4);
		t_damage_type = AT_LIGHTNING;
		T_Damage (trace_ent, from, from, damage);
		if (self.classname == "player")
		{
			if (other.classname == "player")
				trace_ent.velocity_z = trace_ent.velocity_z + 400;
		}
	}
	e1 = trace_ent;

	traceline (p1 + f, p2 + f, FALSE, self);
	if (trace_ent != e1 && trace_ent.takedamage)
	{
		particle (trace_endpos, '0 0 100', 225, damage*4);
		t_damage_type = AT_LIGHTNING;
		T_Damage (trace_ent, from, from, damage);
	}
	e2 = trace_ent;

	traceline (p1 - f, p2 - f, FALSE, self);
	if (trace_ent != e1 && trace_ent != e2 && trace_ent.takedamage)
	{
		particle (trace_endpos, '0 0 100', 225, damage*4);
		t_damage_type = AT_LIGHTNING;
		T_Damage (trace_ent, from, from, damage);
	}
};


void() W_FireLightning =
{
	local	vector		org;
	local	float		cells;

// explode if under water
	if (self.waterlevel > 1)
	{
		t_damage_type = AT_LIGHTNING;
		T_RadiusDamage (self, self, 1500, world);
		return;
	}

//      sound (self, CHAN_AUTO, "weapons/lstart.wav", 1, ATTN_NORM);

	if (self.t_width < time)
	{
		sound (self, CHAN_WEAPON, "weapons/lhit.wav", 1, ATTN_NORM);
		self.t_width = time + 0.6;
	}
	self.punchangle_x = -2;

	org = self.origin + '0 0 16';
	
	traceline (org, org + v_forward*600, TRUE, self);

	WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
	WriteByte (MSG_BROADCAST, TE_LIGHTNING2);
	WriteEntity (MSG_BROADCAST, self);
	WriteCoord (MSG_BROADCAST, org_x);
	WriteCoord (MSG_BROADCAST, org_y);
	WriteCoord (MSG_BROADCAST, org_z);
	WriteCoord (MSG_BROADCAST, trace_endpos_x);
	WriteCoord (MSG_BROADCAST, trace_endpos_y);
	WriteCoord (MSG_BROADCAST, trace_endpos_z);

	LightningDamage (self.origin, trace_endpos + v_forward*4, self, 30);
};


//=============================================================================

void() GrenadeExplode = {
	t_damage_type = AT_EXPLOSION;
	T_RadiusDamage (self, self.owner, 120, world);

	WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
	WriteByte (MSG_BROADCAST, TE_EXPLOSION);
	WriteCoord (MSG_BROADCAST, self.origin_x);
	WriteCoord (MSG_BROADCAST, self.origin_y);
	WriteCoord (MSG_BROADCAST, self.origin_z);

	BecomeExplosion ();
};

void() GrenadeTouch =
{
	if (other == self.owner)
		return;		// don't explode on owner
	if (other.takedamage == DAMAGE_AIM)
	{
		GrenadeExplode();
		return;
	}
	sound (self, CHAN_WEAPON, "weapons/bounce.wav", 1, ATTN_NORM);	// bounce sound
	if (self.velocity == '0 0 0')
		self.avelocity = '0 0 0';
};

/*
================
W_FireGrenade
================
*/
void() W_FireGrenade =
{
	local	entity missile, mpuff;
	
	sound (self, CHAN_WEAPON, "weapons/grenade.wav", 1, ATTN_NORM);

	self.punchangle_x = -2;

	missile = spawn ();
	missile.owner = self;
	missile.movetype = MOVETYPE_BOUNCE;
	missile.solid = SOLID_BBOX;
	missile.classname = "grenade";
		
// set missile speed	

	Biggun_Aim (self.v_angle);

	missile.velocity = v_forward*600 + v_up * 200 + crandom()*v_right*10 + crandom()*v_up*10;

	missile.avelocity = '300 300 300';

	missile.angles = vectoangles(missile.velocity);
	
	missile.touch = GrenadeTouch;
	
// set missile duration
	missile.nextthink = time + 2.5;
	missile.think = GrenadeExplode;

	setmodel (missile, "progs/grenade.mdl");
	setsize (missile, '0 0 0', '0 0 0');		
	setorigin (missile, self.origin);
};


//=============================================================================

void() spike_touch;
void() superspike_touch;


/*
===============
launch_spike

Used for both the player and the ogre
===============
*/
void(vector org, vector dir) launch_spike =
{
	newmis = spawn ();
	newmis.owner = self;
	newmis.movetype = MOVETYPE_FLYMISSILE;
	newmis.solid = SOLID_BBOX;

	newmis.angles = vectoangles(dir);
	
	newmis.touch = spike_touch;
	newmis.classname = "spike";
	newmis.think = SUB_Remove;
	newmis.nextthink = time + 6;
	setmodel (newmis, "progs/spike.mdl");
	setsize (newmis, VEC_ORIGIN, VEC_ORIGIN);		
	setorigin (newmis, org);

	newmis.velocity = dir * 1000;
};

void() W_FireSuperSpikes =
{
	local vector	dir;
	local entity	old;

	Biggun_Aim (self.v_angle);
	
	sound (self, CHAN_WEAPON, "weapons/spike2.wav", 1, ATTN_NORM);
	dir = aim (self, 1000);
	launch_spike (self.origin + '0 0 16', dir);
	newmis.touch = superspike_touch;
	setmodel (newmis, "progs/s_spike.mdl");
	setsize (newmis, VEC_ORIGIN, VEC_ORIGIN);		
	self.punchangle_x = -2;
};

void() W_FireSpikes =
{
	local vector	dir;
	local entity	old;

	local float ox, f;
	
	Biggun_Aim (self.v_angle);

	f = floor(10.0 * time);

	if (f & 1) ox = 4;
	else ox = -4;


	sound (self, CHAN_WEAPON, "weapons/rocket1i.wav", 1, ATTN_NORM);
	dir = aim (self, 1000);
	launch_spike (self.origin + '0 0 16' + v_right*ox, dir);

	self.punchangle_x = -2;
};



.float hit_z;
void() spike_touch =
{
	local float rand;
	if (other == self.owner)
		return;

	if (other.solid == SOLID_TRIGGER)
		return;	// trigger field, do nothing

	if (pointcontents(self.origin) == CONTENT_SKY)
	{
		remove(self);
		return;
	}
	
// hit something that bleeds
	if (other.takedamage)
	{
		spawn_touchblood (9);
		t_damage_type = AT_NAILS;
		T_Damage (other, self, self.owner, 9);
	}
	else
	{
		WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
		
		if (self.classname == "wizspike")
			WriteByte (MSG_BROADCAST, TE_WIZSPIKE);
		else if (self.classname == "knightspike")
			WriteByte (MSG_BROADCAST, TE_KNIGHTSPIKE);
		else
			WriteByte (MSG_BROADCAST, TE_SPIKE);
		WriteCoord (MSG_BROADCAST, self.origin_x);
		WriteCoord (MSG_BROADCAST, self.origin_y);
		WriteCoord (MSG_BROADCAST, self.origin_z);
	}

	remove(self);

};

void() superspike_touch =
{
local float rand;
	if (other == self.owner)
		return;

	if (other.solid == SOLID_TRIGGER)
		return;	// trigger field, do nothing

	if (pointcontents(self.origin) == CONTENT_SKY)
	{
		remove(self);
		return;
	}
	
// hit something that bleeds
	if (other.takedamage)
	{
		spawn_touchblood (18);
		t_damage_type = AT_NAILS;
		T_Damage (other, self, self.owner, 18);
	}
	else
	{
		WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
		WriteByte (MSG_BROADCAST, TE_SUPERSPIKE);
		WriteCoord (MSG_BROADCAST, self.origin_x);
		WriteCoord (MSG_BROADCAST, self.origin_y);
		WriteCoord (MSG_BROADCAST, self.origin_z);
	}

	remove(self);

};



//MINE MINE MINE MINE MINE

// USED FOR THE BURLY NAILGUN
//THE HUNTER SEEKER
//AUTOAIM RUNE

void() HSAThink = {
	local   float   len, bestlen, dot, cont;
	local   entity  head, besthead;
	local   vector  org, vnorm, del;


	self.nextthink = time + 0.3;

		//if the owner is dead then this is too
	if (self.owner.health <= 0)
	{
		self.owner.hsa = world;
		remove(self);
		return;
	}

	if (self.enemy.health <= 0) self.enemy = world;
	if (self.enemy.takedamage == DAMAGE_NO) self.enemy = world;

//if the owner isnt selected on this weapon... forget about seeking
	if (self.owner.player_attack_func != W_FireBurlyNailgun &&
	    self.owner.player_attack_func != W_FireHunterSeeker &&
	    self.owner.rune_autoaim_count == 0)
	    return;

	bestlen = -1;
	besthead = world;

	setorigin(self, self.owner.origin);

	makevectors(self.owner.v_angle);
	vnorm = v_forward;


	head = findradius(self.owner.origin, 2048);


	while (head)
	{
		cont = TRUE;

		if (head == self.owner) cont = FALSE;
				//if teamplay is set then NO TARGETTING YOUR BUDDIES
		if ((head.team == self.owner.team) && (teamplay)) cont = FALSE;
		if (head.health <= 0) cont = FALSE;
		if (head.takedamage == DAMAGE_NO) cont = FALSE;


		org = (head.absmax + head.absmin) * 0.5;
		traceline(self.owner.origin + self.owner.view_ofs, org, FALSE, self.owner);
		if ((trace_fraction < 1.0) && (trace_ent != head)) cont = FALSE;

		if (cont)
		{

			del = org - self.owner.origin;

			len = vlen(del);

			del = normalize(del);
			dot = vnorm_x * del_x + vnorm_y * del_y + vnorm_z * del_z;

			//what this says is only continue if head is a monster or -
			// - if head is a switch/door and you're aiming right at it
			if ((head.takedamage != DAMAGE_YES) || (dot > 0.99))
			{

				dot = 1.0 - (dot * 0.5 + 0.5);
				len = len * dot;

				if (bestlen == -1 || len < bestlen)
				{
					bestlen = len;
					besthead = head;
				}
			}
		}

		head = head.chain;
	}

//grab the new enemy
	if ((bestlen < 4000) && (besthead != world))
		self.enemy = besthead;

//if there wasnt any then bail
	if (self.enemy == world) return;


//display targetting

	//only display target glow if set to burly nailgun or hunter seeker

	if (self.owner.player_attack_func == W_FireBurlyNailgun ||
	    self.owner.player_attack_func == W_FireHunterSeeker)
	{
		org = (self.enemy.absmax + self.enemy.absmin) * 0.5;

		head = msg_entity;
		msg_entity = self.owner;

		WriteByte (MSG_ONE, SVC_TEMPENTITY);
		WriteByte (MSG_ONE, TE_TELEPORT);
		WriteCoord (MSG_ONE, org_x);
		WriteCoord (MSG_ONE, org_y);
		WriteCoord (MSG_ONE, org_z);

		WriteByte (MSG_ONE, SVC_TEMPENTITY);
		WriteByte (MSG_ONE, TE_LAVASPLASH);
		WriteCoord (MSG_ONE, org_x);
		WriteCoord (MSG_ONE, org_y);
		WriteCoord (MSG_ONE, org_z);

		msg_entity = head;
	}

	//only display laser site if set to burly nailgun or hunter seeker

	if (self.owner.player_attack_func == W_FireBurlyNailgun ||
	    self.owner.player_attack_func == W_FireHunterSeeker)
	{
		if (self.enemy)
		{
			self.lip = self.lip + 1;

			if (self.lip >= 10)
			{
				self.lip = 0;
	
	
				del = (self.enemy.absmax + self.enemy.absmin) * 0.5;
				org = self.owner.origin;
	
				head = msg_entity;
				msg_entity = self.owner;
			
				WriteByte (MSG_ONE, SVC_TEMPENTITY);
				WriteByte (MSG_ONE, TE_LIGHTNING1);
				WriteEntity(MSG_ONE, self);
				WriteCoord (MSG_ONE, org_x);
				WriteCoord (MSG_ONE, org_y);
				WriteCoord (MSG_ONE, org_z);
				WriteCoord (MSG_ONE, del_x);
				WriteCoord (MSG_ONE, del_y);
				WriteCoord (MSG_ONE, del_z);
	
				msg_entity = head;
			}
		}
	}
};

void() CreateHSA =
{
	local entity e;
	e = spawn();
	self.hsa = e;

	e.owner = self;

	e.classname = "hunter seeker algorithm";

	e.solid = SOLID_NOT;
	e.movetype = MOVETYPE_FLY;

	setorigin(e, self.origin);
	setsize(e, '0 0 0', '0 0 0');

	e.nextthink = time + 0.1;
	e.think = HSAThink;
};

// USED FOR THE BIGASS SHOTGUN

void(float shotcount, vector dir, vector spread, float damg) FireMyBullets =
{
	local	vector direction;
	local	vector	src;
	
	Biggun_Aim(self.v_angle);

	src = self.origin + v_forward*10;
	src_z = self.absmin_z + self.size_z * 0.7;

	ClearMultiDamage();
	while (shotcount > 0) {
		direction = dir + crandom()*spread_x*v_right + crandom()*spread_y*v_up;

		traceline (src, src + direction*2048, FALSE, self);
		if (trace_fraction != 1.0)
			TraceAttack (damg, direction);

		shotcount = shotcount - 1;
	}
	ApplyMultiDamage ();
};

//WEAPONS...

void() PoisonTouchedThink;


// ************************** SCRAMBLED EGGS **************************

void(vector org, vector vel) MakeEggs = {
	local	entity	missile;
	missile = spawn ();
	missile.owner = self.owner;
        missile.movetype = MOVETYPE_BOUNCE;
	missile.solid = SOLID_BBOX;
        missile.classname = "acid_eggs";
	missile.velocity = vel;
	missile.angles = vectoangles(missile.velocity);
        missile.nextthink = time + 0.4;
        missile.think = GrenadeExplode;
        missile.touch = GrenadeTouch;
        setmodel (missile, "progs/grenade.mdl");
        setsize (missile, '0 0 0', '0 0 0');     
	setorigin (missile, org);
};

void() AcidEggs = {
	local vector v, nail_dest;
	local float  t, dot;
	self.nextthink = time + 0.1;

	//have 'self' track whatever it hit...
//        self.velocity = self.enemy.velocity;

        t = random() * 2;
	while (t > 0) {
                do {
			v_x = crandom();
			v_y = crandom();
			v_z = crandom();
                        v = normalize(v);
			dot = v * self.spawn_origin;
                } while (dot <= 0.96);
                MakeEggs(self.origin + v * 32, v * 600);
		t = t - 1;
	}
        if (self.attack_finished < time) {
                remove(self);
        }
};

void() W_FireScrambledEggs = {

	local   entity  bullet;
	local   vector  dir;

        self.attack_finished = time + 2.5;

	sound (self, CHAN_WEAPON, "weapons/spike2.wav", 1, ATTN_NORM);
	self.punchangle_x = -2;

	Biggun_Aim(self.v_angle);

	bullet = spawn();
	bullet.owner = self;
        bullet.movetype = MOVETYPE_NOCLIP;//MOVETYPE_FLYMISSILE;
        bullet.solid = SOLID_NOT;
        bullet.classname = "eggs_spawn";
        bullet.velocity  = v_forward * 1000;
        bullet.angles = vectoangles(bullet.velocity);
        bullet.nextthink = time + 0.1;
        bullet.think = AcidEggs;
//        bullet.touch = eggs_touch;
        bullet.spawn_origin = v_forward;
        bullet.attack_finished = time + 2.5;

        setmodel (bullet, "progs/s_spike.mdl");
        setsize (bullet, '0 0 0', '0 0 0');
        setorigin(bullet, self.origin);
};

// ************************** VACCUUM MORTAR ***************************

void() VaccuumExplode =
{
	t_damage_type = AT_EXPLOSION;
	T_RadiusDamage (self, self.owner, 220, world);

	WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
	WriteByte (MSG_BROADCAST, TE_TAREXPLOSION);
	WriteCoord (MSG_BROADCAST, self.origin_x);
	WriteCoord (MSG_BROADCAST, self.origin_y);
	WriteCoord (MSG_BROADCAST, self.origin_z);

	BecomeExplosion ();
};

void() VaccuumSuck =
{
	local	float 	points;
	local	entity	head;
	local   vector  org, dir;

//	sound (other, CHAN_AUTO, "ambience/windfly.wav", 1, ATTN_NORM);

	head = findradius(self.origin, 300);
	
	while (head) {
                if (    (head != world) &&
                        (head.movetype) &&
			(head.movetype != MOVETYPE_PUSH) &&
			(!(head.flags & FL_ITEM)) &&
			(!(head.classname == "grap_hook" && head.enemy != world)) &&		//only pull in grap hooks if they're not hooked on anything
			(head != self.owner) &&
			((teamplay != 1) || (head.team != self.owner.team)) )
		{
			org = head.origin + (head.mins + head.maxs)*0.5;
			points = 0.5*vlen (self.origin - org);
			if (points < 0) points = 0;
			points = 300 - points;
			
			if (head.classname == "grap_hook") {
				points = points * 100;
			} else {
				points = 2.0 * points;
			}
			
			dir = head.origin - self.origin;
			dir = normalize(dir);
			head.flags = head.flags - (head.flags & FL_ONGROUND);
			head.velocity = head.velocity - dir*points;
		}
		head = head.chain;
	}

	self.nextthink = time + 0.1;
	if (self.attack_finished < time) VaccuumExplode();
};

void() VaccuumThink =
{
	self.nextthink = time + 0.1;
	self.angles = vectoangles(self.velocity);

	VaccuumSuck();
};

void() T_VaccuumTouch =
{
	self.movetype = MOVETYPE_NONE;
	self.attack_finished = time + 4;
	self.avelocity = '300 300 300';
	VaccuumSuck();
};

void() W_FireVaccuumMortar = {
	local	entity missile, mpuff;
	
	self.attack_finished = time + 2;

	sound (self, CHAN_WEAPON, "weapons/sgun1.wav", 1, ATTN_NORM);

	self.punchangle_x = -2;

	missile = spawn ();
	missile.owner = self;
	missile.movetype = MOVETYPE_TOSS;
	missile.solid = SOLID_BBOX;
	missile.classname = "vmortar";
		
// set missile speed	

	Biggun_Aim (self.v_angle);
	missile.velocity = v_forward * 1200 + v_up * 100;
	missile.angles = vectoangles(missile.velocity);
	
	missile.touch = T_VaccuumTouch;
	missile.attack_finished = time + 2;
	
	missile.nextthink = time + 0.1;
	missile.think = VaccuumThink;

	setmodel (missile, "progs/missile.mdl");
	setsize (missile, '0 0 0', '0 0 0');		
	setorigin (missile, self.origin + v_forward*8 + '0 0 16');
};

// ************************** FAT GUN ***************************

void() W_FireFatGun = {
	local	vector	source;
	local	vector	org;

	if (!self.rune_burst_count) {
		self.attack_finished = time + 0.6;
	} else {
		self.attack_finished = time + 0.3;
	}

	sound (self, CHAN_WEAPON, "weapons/ric1.wav", 1, ATTN_NORM); 

	Biggun_Aim (self.v_angle);
	source = self.origin + '0 0 16';
	traceline (source, source + v_forward*2048, FALSE, self);
	if (trace_fraction == 1.0) {
		return;
	}
	
	org = trace_endpos - v_forward*4;

	if (trace_ent.takedamage) {
		SpawnBlood (org, '0 0 0', 20);
		t_damage_type = AT_BULLETS;
		if (self.rune_burst_count) {
			t_damage_kill = 1;
		}
		T_Damage (trace_ent, self, self, 500);
	} else {
		// hit wall
		WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
		WriteByte (MSG_BROADCAST, TE_GUNSHOT);
		WriteCoord (MSG_BROADCAST, org_x);
		WriteCoord (MSG_BROADCAST, org_y);
		WriteCoord (MSG_BROADCAST, org_z);
	}
};

// ************************** HEAD BOMBS ***************************

void() Shockwave = [0, Shockwave] {
	WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
	WriteByte (MSG_BROADCAST, TE_LIGHTNING3);
	WriteEntity (MSG_BROADCAST, self);
	WriteCoord (MSG_BROADCAST, self.origin_x);
	WriteCoord (MSG_BROADCAST, self.origin_y);
	WriteCoord (MSG_BROADCAST, self.origin_z);
	WriteCoord (MSG_BROADCAST, self.bomb_sight.origin_x);
	WriteCoord (MSG_BROADCAST, self.bomb_sight.origin_y);
	WriteCoord (MSG_BROADCAST, self.bomb_sight.origin_z);

	LightningDamage (self.origin, self.bomb_sight.origin, self.owner, 300);

	self.ammo_cells = self.ammo_cells + 1;
	if (self.ammo_cells == 25)
		remove(self);
};

void() MakeShockWave = {
	local entity wave1, wave2, wave3, wave4, wave5;
	local vector fwd, fwd_72, fwd_144, right_72, right_144;

	fwd_x = crandom() * 90.0;
	fwd_y = random() * 360.0;
	fwd_z = 0;

	Biggun_Aim (fwd);

	wave1 = spawn();
	wave2 = spawn();
	wave3 = spawn();
	wave4 = spawn();
	wave5 = spawn();

	wave1.owner = self.owner;
	wave2.owner = self.owner;
	wave3.owner = self.owner;
	wave4.owner = self.owner;
	wave5.owner = self.owner;

	wave1.movetype = MOVETYPE_FLYMISSILE;
	wave2.movetype = MOVETYPE_FLYMISSILE;
	wave3.movetype = MOVETYPE_FLYMISSILE;
	wave4.movetype = MOVETYPE_FLYMISSILE;
	wave5.movetype = MOVETYPE_FLYMISSILE;

	wave1.solid = SOLID_BBOX;
	wave2.solid = SOLID_BBOX;
	wave3.solid = SOLID_BBOX;
	wave4.solid = SOLID_BBOX;
	wave5.solid = SOLID_BBOX;

	wave1.classname = "the_wave";
	wave2.classname = "the_wave";
	wave3.classname = "the_wave";
	wave4.classname = "the_wave";
	wave5.classname = "the_wave";

	fwd_72 = 185 * v_forward;
	fwd_144 = -485 * v_forward;

	right_72 = v_right * 570;
	right_144 = v_right * 352;

	//0 degrees
	wave1.velocity = v_forward * 600;
	//72 degrees
	wave2.velocity = fwd_72 + right_72;
	//144 degrees
	wave3.velocity = fwd_144 + right_144;
	//216 degrees
	wave4.velocity = fwd_144 - right_144;
	//288 degrees
	wave5.velocity = fwd_72 - right_72;

	wave1.nextthink = time + 0.1;
	wave2.nextthink = time + 0.1;
	wave3.nextthink = time + 0.1;
	wave4.nextthink = time + 0.1;
	wave5.nextthink = time + 0.1;

	wave1.think = Shockwave;
	wave2.think = Shockwave;
	wave3.think = Shockwave;
	wave4.think = Shockwave;
	wave5.think = Shockwave;

	wave1.bomb_sight = wave2;
	wave2.bomb_sight = wave3;
	wave3.bomb_sight = wave4;
	wave4.bomb_sight = wave5;
	wave5.bomb_sight = wave1;

	setorigin (wave1, self.origin + '0 0 32');
	setorigin (wave2, self.origin + '0 0 32');
	setorigin (wave3, self.origin + '0 0 32');
	setorigin (wave4, self.origin + '0 0 32');
	setorigin (wave5, self.origin + '0 0 32');


};

void() MegaBombExplode = {

	sound (self, CHAN_WEAPON, "weapons/r_exp3.wav", 1, ATTN_NORM);

	WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
	WriteByte (MSG_BROADCAST, TE_LAVASPLASH);
	WriteCoord (MSG_BROADCAST, self.origin_x);
	WriteCoord (MSG_BROADCAST, self.origin_y);
	WriteCoord (MSG_BROADCAST, self.origin_z);

	MakeShockWave();

        T_RadiusDamage (self, self.owner, 500, self);

	BecomeExplosion ();
};

void() MegaBombCheckOwner = [0, MegaBombCheckOwner] {
	if (self.owner.deadflag) {
		self.think = MegaBombExplode;
	}
};

void() MegaBombBounce = {
	local float rs;
	rs = rint((random() * 5) + 1);

	if (rs == 1) {
		self.noise = "player/pain1.wav";
	} else if (rs == 2) {
		self.noise = "player/pain2.wav";
	} else if (rs == 3) {
		self.noise = "player/pain3.wav";
	} else if (rs == 4) {
		self.noise = "player/pain4.wav";
	} else if (rs == 5) {
		self.noise = "player/pain5.wav";
	} else {
		self.noise = "player/pain6.wav";
	}

	sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);

	if (self.velocity == '0 0 0') {
		self.avelocity = '0 0 0';
	}

        if (other.takedamage == DAMAGE_AIM && other != self.owner) {
                MegaBombExplode();
                return;
        }
};

void() W_FireMegaBomb = {
	local   entity missile;

	if (!self.rune_burst_count) {
		self.attack_finished = time + 1;
	} else {
		self.attack_finished = time + 0.3;
	}

	if (self.bomb_sight) {
		self.bomb_sight.nextthink = time + 0.1;
		self.bomb_sight.think = MegaBombExplode;
		self.bomb_sight = world;
		return;
	}
	
	sound (self, CHAN_WEAPON, "weapons/grenade.wav", 1, ATTN_NORM);

	self.punchangle_x = -2;

	missile = spawn ();
	missile.owner = self;
	self.bomb_sight = missile;
	missile.movetype = MOVETYPE_BOUNCE;
        missile.solid = SOLID_TRIGGER;
	missile.classname = "mega_bomb";
		
	Biggun_Aim(self.v_angle);
	missile.velocity = v_forward * 1200 + v_up * 100;

	missile.avelocity = '300 300 300';
	missile.angles = vcrandom() * 300;
	
	missile.touch = MegaBombBounce;
	missile.think = MegaBombCheckOwner;
	missile.nextthink = time + 0.1;

	setmodel (missile, "progs/h_player.mdl");
        setsize (missile, '0 0 0', '0 0 0');
	setorigin (missile, self.origin);
};

// ************************** PINDICATOR ***************************

void() NetNoClipAgain = {
	local	vector	source;
	local   vector  org, dir;

	self.nextthink = time + 0.1;

	source = self.origin;

	traceline (source, source + self.angles*2048, FALSE, self);


	particle (trace_endpos, 100 * self.angles, 107, 50);

	if (trace_fraction == 1.0)
	{
		remove(self);
		return;
	}

	org = trace_endpos - self.angles;

	particle (trace_endpos, -100 * self.angles, 107, 50);

	if (trace_ent.takedamage) {
		t_damage_type = AT_NAILS;
		T_Damage (trace_ent, self.owner, self.owner, 5);
		setorigin(self, trace_endpos);
	} else {
		setorigin(self, trace_endpos + self.angles * 16);
		self.ammo_shells = self.ammo_shells - 1;
		if (self.ammo_shells == 0) remove(self);
		return;
	}

        if (    (trace_ent != world) &&
                (trace_ent.movetype) &&
                (trace_ent.movetype != MOVETYPE_PUSH))
	{
		trace_ent.flags = trace_ent.flags - (trace_ent.flags & FL_ONGROUND);
		trace_ent.velocity = self.angles * 600;
		trace_ent.velocity_z = trace_ent.velocity_z + 50;
	}
};

void() W_FirePindicator = {

	local   entity bullet;
	local	vector	source;
	local   vector  org, dir;

	self.attack_finished = time + 0.1;

	sound (self, CHAN_WEAPON, "weapons/ric1.wav", 1, ATTN_NORM); 

	self.punchangle_x = -2;
	bullet = spawn ();
	bullet.owner = self;
	bullet.movetype = MOVETYPE_NONE;
	bullet.solid = SOLID_NOT;
	bullet.classname = "netshot";

	Biggun_Aim(self.v_angle);

	//preserve the forward direction
	bullet.angles = v_forward;

	source = self.origin + '0 0 16';
	traceline (source, source + v_forward*2048, FALSE, self);

	if (trace_fraction == 1.0)
	{
		remove(bullet);
		return;
	}
	
	org = trace_endpos - v_forward*4;
	setorigin(bullet, trace_endpos);

	particle (trace_endpos, -100 * v_forward, 107, 50);

	if (trace_ent.takedamage) {
		t_damage_type = AT_NAILS;
		T_Damage (trace_ent, self, self, 10);
	}
	
        if (    (trace_ent != world) &&
                (trace_ent.movetype) &&
                (trace_ent.movetype != MOVETYPE_PUSH))
        {
		trace_ent.flags = trace_ent.flags - (trace_ent.flags & FL_ONGROUND);
		trace_ent.velocity = v_forward * 600;
		trace_ent.velocity_z = trace_ent.velocity_z + 50;
	}

	bullet.nextthink = time + 0.1;
	bullet.think = NetNoClipAgain;
	bullet.ammo_shells = 20;
};

// ******************** RAIN MAN *********************

void() rain_touch = {
	local float rand;
	if (other == self.owner)
		return;

	if (other.solid == SOLID_TRIGGER)
		return;	// trigger field, do nothing
	
// hit something that bleeds
	if (other.takedamage) {
		spawn_touchblood (15);
		t_damage_type = AT_NAILS;
                T_Damage (other, self, self.owner, 12);
	} else {
		WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
		WriteByte (MSG_BROADCAST, TE_SUPERSPIKE);
		WriteCoord (MSG_BROADCAST, self.origin_x);
		WriteCoord (MSG_BROADCAST, self.origin_y);
		WriteCoord (MSG_BROADCAST, self.origin_z);
	}

	remove(self);

};

void(vector org, vector vel) MakeRain = {
	local	entity	missile;
	missile = spawn ();
	missile.owner = self.owner;
	missile.movetype = MOVETYPE_FLYMISSILE;
	missile.solid = SOLID_BBOX;
	missile.classname = "acid_rain";
	missile.velocity = vel;
	missile.angles = vectoangles(missile.velocity);
	missile.nextthink = time + 5;
	missile.think = SUB_Remove;
	missile.touch = rain_touch;
	setmodel (missile, "progs/s_spike.mdl");
        setsize (missile, '0 0 0', '0 0 0');     
	setorigin (missile, org);
};

void() AcidRain = {
	local vector v, nail_dest;
	local float  t, dot;
	self.nextthink = time + 0.1;

	//have 'self' track whatever it hit...
//        self.velocity = self.enemy.velocity;

	t = 2 + random() * 2;
	while (t > 0) {
                do {
			v_x = crandom();
			v_y = crandom();
			v_z = crandom();
                        v = normalize(v);
			dot = v * self.spawn_origin;
                } while (dot <= 0.96);
    //            nail_dest = self.origin + v * 2048 + self.spawn_origin * 10;
  //              traceline (self.origin, nail_dest, TRUE, self);
//                MakeRain (trace_endpos + v * -10, v * -1000);
                MakeRain(self.origin + v * 32, v * 600);
		t = t - 1;
	}
        if (self.attack_finished < time) {
                remove(self);
        }
};

void() W_FireRainGun = {

	local   entity  bullet;
	local   vector  dir;

        self.attack_finished = time + 0.4;

	sound (self, CHAN_WEAPON, "weapons/spike2.wav", 1, ATTN_NORM);
	self.punchangle_x = -2;

	Biggun_Aim(self.v_angle);

	bullet = spawn();
	bullet.owner = self;
        bullet.movetype = MOVETYPE_NOCLIP;//MOVETYPE_FLYMISSILE;
        bullet.solid = SOLID_NOT;
        bullet.classname = "rain_spawn";
        bullet.velocity  = v_forward * 1000;
        bullet.angles = vectoangles(bullet.velocity);
        bullet.nextthink = time + 0.1;
        bullet.think = AcidRain;
        bullet.touch = rain_touch;
        bullet.spawn_origin = v_forward;
        bullet.attack_finished = time + 2.5;

        setmodel (bullet, "progs/s_spike.mdl");
        setsize (bullet, '0 0 0', '0 0 0');
        setorigin(bullet, self.origin);
};

// ******************** MAD DOG TANNON CANNON *********************

void() MadDogTannonGoMad =
{
	local entity stemp;
	local vector del, vrand;
	local float dot;

	self.nextthink = time + 0.1;

	if (self.owner.health <= 0)
	{
		remove(self);
		return;
	}

	stemp = self;
	self = self.owner;
	Biggun_Aim(self.v_angle);
	self = stemp;

//        if (self.owner.rune_burst_count == 0) {

		dot = v_forward * self.dest1;

		dot = (1 - dot) * 0.05;
		if (dot < 0.3) dot = 0.3;

		del = v_forward - self.dest1;
		del = del * dot;


		vrand = vcrandom();

		self.dest2 = self.dest2 + del + vrand * 0.04;

		self.dest1 = self.dest1 + self.dest2;
		self.dest1 = normalize(self.dest1);
//        } else {
//                self.dest1 = v_forward;
//                self.dest2 = '0 0 0';
//        }

	stemp = self;
	self = self.owner;

        FireMyBullets (1, stemp.dest1, '0.01 0.01 0', 20);

	self = stemp;

	self.ammo_shells = self.ammo_shells - 1;
	if (self.ammo_shells < 0) self.think = SUB_Remove;
};

void() W_FireMadDogTannon = {
	local entity e;
        local float f;

	self.attack_finished = time + 10;

        f = self.owner.rune_burst_count + 1;
        while (f > 0) {

                f = f - 1;

                e = spawn();

                e.movetype = MOVETYPE_NONE;
                e.solid = SOLID_NOT;

                setsize(e, '0 0 0', '0 0 0');
                setorigin(e, self.origin);

                e.owner = self;
                e.think = MadDogTannonGoMad;
                e.nextthink = time + 0.1;

                Biggun_Aim(self.v_angle);

                e.dest1 = v_forward + v_right*0.1*crandom() + v_up*0.1*crandom();
                e.dest1 = normalize(e.dest1);

                e.dest2 = '0 0 0';

                e.ammo_shells = 250;
        }
};


// ************************** MAD GUN **************************

void() MadGunSeek;

void() MadGunGo = {
	local float frac;
	local vector src, dst;

	self.nextthink = time + 0.1;

	src = self.dest1;       //the source
	dst = self.origin;	//the dest

	WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
	WriteByte (MSG_BROADCAST, TE_LIGHTNING2);
	WriteEntity (MSG_BROADCAST, self);
	WriteCoord (MSG_BROADCAST, src_x);
	WriteCoord (MSG_BROADCAST, src_y);
	WriteCoord (MSG_BROADCAST, src_z);
	WriteCoord (MSG_BROADCAST, dst_x);
	WriteCoord (MSG_BROADCAST, dst_y);
	WriteCoord (MSG_BROADCAST, dst_z);

	dst = self.dest;

	self.ammo_nails = self.ammo_nails + 1;
	frac = self.ammo_nails / self.ammo_cells;

	src = (dst - src) * frac + src;

	setorigin(self, src);

	t_damage_type = AT_LIGHTNING;
        T_RadiusDamage(self, self.owner, 60, self.owner);

	if (self.ammo_nails >= self.ammo_cells) self.think = MadGunSeek;
};

void() MadGunSeek = {
	local vector    vrand,  destl,   bestdest;
	local float     try,    len,    bestlen;

	bestlen = -1;

	try = 0;
	while (try < 10) {
		try = try + 1;

		vrand_x = crandom();
		vrand_y = crandom();
		vrand_z = crandom();
		vrand = vrand * 2048;
		traceline (self.origin, self.origin + vrand, FALSE, self);

		destl = self.origin * 0.1 + trace_endpos * 0.9;
		len = vlen(destl - self.origin);

		if (len > bestlen) {
			bestlen = len;
			bestdest = destl;
		}
	}

	self.dest1 = self.origin;
	self.dest = bestdest;

	self.think = MadGunGo;
	self.nextthink = time + 0.1;

	//the go count
	self.ammo_nails = 0;
	self.ammo_cells = bestlen * 0.01 + 1;

	//the seek count
	self.ammo_shells = self.ammo_shells - 1;
	if (self.ammo_shells <= 0) {
		remove(self);
		return;
	}
};

void() W_FireMadGun = {

	local vector src, destl;
	local entity e;

	self.attack_finished = time + 1.1;

	Biggun_Aim(self.v_angle);

	src = self.origin + v_forward*10;
	src_z = self.absmin_z + self.size_z * 0.7;

	traceline (src, src + v_forward*2048, FALSE, self);

	destl = src * 0.1 + trace_endpos * 0.9;

	e = spawn();

	e.movetype = MOVETYPE_NONE;
	e.solid = SOLID_NOT;

	setmodel(e, "progs/spike.mdl");
	setsize(e, '0 0 0', '0 0 0');
	setorigin(e, destl);

	e.avelocity = '300 300 300';
	e.effects = e.effects | EF_BRIGHTFIELD;

	e.owner = self;

	e.think = MadGunSeek;
	e.nextthink = time + 0.1;

	if (!self.rune_burst_count) {
		e.ammo_shells = 3;
	} else {
		e.ammo_shells = 6;
	}
};

// ************************** CLUSTER GRENADE **************************

void() ClusterGrenadeSecExplode = {
	t_damage_type = AT_EXPLOSION;
	if (!self.owner.rune_burst_count) {
		T_RadiusDamage (self, self.owner, 120, world);
	} else {
		T_RadiusDamage (self, self.owner, 120, self.owner);
	}

	WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
	WriteByte (MSG_BROADCAST, TE_EXPLOSION);
	WriteCoord (MSG_BROADCAST, self.origin_x);
	WriteCoord (MSG_BROADCAST, self.origin_y);
	WriteCoord (MSG_BROADCAST, self.origin_z);

	BecomeExplosion ();
};

void() ClusterGrenadeSecTouch = {

	local vector vang, tvel;
	local entity e;

	traceline(self.origin, self.origin + self.velocity, FALSE, self);

	if (trace_fraction == 1.0) {
		tvel = normalize('0 0 0' - self.dest);
	} else {
		tvel = trace_plane_normal;
	}

	vang = vcrandom();
	vang = vang + tvel;

	e = spawn();

	e.owner = self.owner;

	e.velocity = vang * 1000;
	e.dest = ('0 0 0' - tvel) * random() * 150; //accel per frame

	e.ammo_nails = floor(2 + random() + 5);

	e.movetype = MOVETYPE_FLYMISSILE;
	e.solid = SOLID_BBOX;

	setmodel(e, "progs/grenade.mdl");

	e.avelocity = '300 300 300';

	setsize (e, '0 0 0', '0 0 0');
	setorigin(e, self.origin);

	e.touch = ClusterGrenadeSecExplode;

	remove(self);
};

void() ClusterGrenadeTouch = {
	local entity e;
	local float theta;
	local vector vang;

//TODO: add in some vector math - rotate 360 degrees around the plane's normal

	//create an explosion

	t_damage_type = AT_EXPLOSION;
	if (!self.owner.rune_burst_count) {
		T_RadiusDamage (self, self.owner, 120, world);
	} else {
		T_RadiusDamage (self, self.owner, 120, self.owner);
	}


	traceline(self.origin, self.origin + self.velocity, FALSE, self);

	theta = 0;
	while (theta <= 360) {
		theta = theta + 60;

		vang = vcrandom();
		vang = vang + trace_plane_normal;

		e = spawn();
                e.classname = "napalm";

		e.owner = self.owner;

		e.velocity = vang * 1000;
		e.dest = ('0 0 0' - trace_plane_normal) * random() * 150; //accel per frame

		e.ammo_shells = theta;  //the angle

		e.movetype = MOVETYPE_FLYMISSILE;
		e.solid = SOLID_BBOX;

		setmodel(e, "progs/grenade.mdl");

		e.avelocity = '300 300 300';

		setsize (e, '0 0 0', '0 0 0');
		setorigin(e, self.origin + '0 0 10');

		e.touch = ClusterGrenadeSecTouch;
	}

	remove(self);
};

void() W_FireClusterGrenade = {

	local	entity	missile, mpuff;
        local   float   ct;

	self.attack_finished = time + 0.3;

//        if (!self.rune_burst_count) {
//                ct = 1;
//        } else {
//                ct = 2;
//        }                     Sean: causes problems

        ct = 1;

	sound (self, CHAN_WEAPON, "weapons/grenade.wav", 1, ATTN_NORM);

	self.punchangle_x = -2;

	while (ct > 0) {
		ct = ct - 1;

		missile = spawn ();
		missile.owner = self;
		missile.movetype = MOVETYPE_BOUNCE;
		missile.solid = SOLID_BBOX;
		missile.classname = "napalm";

	// set missile speed	

		Biggun_Aim (self.v_angle);

		missile.velocity = v_forward*650 + v_up * 200 + crandom()*v_right*10 + crandom()*v_up*10;
		missile.avelocity = '300 300 300';
		missile.angles = vectoangles(missile.velocity);
		missile.touch = ClusterGrenadeTouch;
		
		setmodel (missile, "progs/grenade.mdl");
		setsize (missile, '0 0 0', '0 0 0');		
		setorigin (missile, self.origin);
	}
};

// ************************** DEATH AXE ************************** 

void() W_FireDeathAxe = {

	local	vector	source;
	local	vector	org;

	self.attack_finished = time + 0.3;

	Biggun_Aim (self.v_angle);
	source = self.origin + '0 0 16';

	if (!self.rune_burst_count) {
		traceline (source, source + v_forward*96, FALSE, self);
	} else {
		traceline (source, source + v_forward*224, FALSE, self);
	}

	if (trace_fraction == 1.0) {
		return;
	}
	
	org = trace_endpos - v_forward*4;

	if (trace_ent.takedamage) {
		SpawnBlood (org, '0 0 0', 20);
		if (trace_ent.classname == "player") {
			t_damage_kill = 2;
		}
		T_Damage (trace_ent, self, self, 50000);
	} else {	// hit wall
		sound (self, CHAN_WEAPON, "player/axhit2.wav", 1, ATTN_NORM);
		WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
		WriteByte (MSG_BROADCAST, TE_GUNSHOT);
		WriteCoord (MSG_BROADCAST, org_x);
		WriteCoord (MSG_BROADCAST, org_y);
		WriteCoord (MSG_BROADCAST, org_z);
	}
};

// ************************** TK AXE ************************** 

void() W_FireTKAxe = {

	local	entity	head;
	local	float	cont, damg;
	local	vector	org;

	self.attack_finished = time + 0.6;

	if (!self.rune_burst_count) {
		damg = 24;
	} else {
                damg = 99;
	}

	head = findradius(self.origin, 2048);

	while (head) {
		cont = TRUE;
		if (head == self) cont = FALSE;
		if (head.health <= 0) cont = FALSE;
		if (head.takedamage == DAMAGE_NO) cont = FALSE;
		if (cont) {
			org = (head.absmax + head.absmin) * 0.5;
			traceline(self.origin + self.view_ofs, org, FALSE, self);
			if ((trace_fraction == 1.0) || (trace_ent == head)) {
				T_Damage(head, self, self, damg);
			}
		}
		head = head.chain;
	}
};

// ************************** GORE SHAFT ************************** 

void() W_FireGoreShaft = {

	local	vector	src;
	local   float   try;

	self.attack_finished = time + 0.6;
	
	sound (self, CHAN_WEAPON, "weapons/guncock.wav", 1, ATTN_NORM);	

	Biggun_Aim(self.v_angle);

	src = self.origin + v_forward*10;
	src_z = self.absmin_z + self.size_z * 0.7;

	do_a_goreshaft = 1;
	FireMyBullets (6, v_forward, '0.04 0.04 0', 6);
	do_a_goreshaft = 0;
};

// ************************** AUTO GRENADE **************************

void() W_FireAutoGrenade = {

	local   entity	missile;
	local	float	ct;
	
	if (!self.rune_burst_count) {
		self.attack_finished = time + 0.1;
		ct = 1;
	} else {
		self.attack_finished = time + 0.3;
                ct = 4;
	}

	sound (self, CHAN_WEAPON, "weapons/grenade.wav", 1, ATTN_NORM);

	self.punchangle_x = -2;

	while (ct > 0) {
		ct = ct - 1;

		missile = spawn ();
		missile.owner = self;
		missile.movetype = MOVETYPE_BOUNCE;
		missile.solid = SOLID_BBOX;
		missile.classname = "auto_grenade";
			
	// set missile speed	

		Biggun_Aim (self.v_angle);

		if (!self.rune_burst_count) {
			missile.velocity = v_forward*1000 + crandom()*v_right*75 + v_up*(100 + random() * 150);
		} else {
			missile.velocity = v_forward*1000 + crandom()*v_right*150 + v_up*(100 + random() * 250);
		}

		missile.avelocity = '300 300 300';

		missile.angles = vectoangles(missile.velocity);
		
		missile.touch = GrenadeTouch;
		
	// set missile duration
		missile.nextthink = time + 0.5 + random();
		missile.think = GrenadeExplode;

		setmodel (missile, "progs/grenade.mdl");
		setsize (missile, '0 0 0', '0 0 0');		
		setorigin (missile, self.origin);
	}
};

// ************************** CHAINGUN **************************

void() W_FireChaingun = {
	local vector dir;

	self.attack_finished = time + 0.1;

	sound (self, CHAN_WEAPON, "weapons/ric2.wav", 1, ATTN_NORM);

	self.punchangle_x = -2;

	Biggun_Aim(self.v_angle);

	if (!self.rune_burst_count) {
		dir = v_forward + v_up * crandom() * 0.03 + v_right * crandom() * 0.1;
                FireMyBullets (10, dir, '0.02 0.02 0', 4);
	} else {
		//times three inaccuracy
		dir = v_forward + v_up * crandom() * 0.09 + v_right * crandom() * 0.3;
		//times three inaccuracy
                FireMyBullets (20, dir, '0.06 0.06 0', 9);
	}
};

// ************************** HUNTER SEEKER **************************


void() HunterSeekerAttack = {

	local vector org;
	local entity missile, en;

	en = self.enemy;
	if ((self.enemy == world) ||
		((teamplay != 0) && (self.enemy.team == self.owner.team)) ||
		(self.enemy.items & IT_INVULNERABILITY))
	{
		remove(self);
		return;
	}

	self.nextthink = time + 0.1;

	org = (en.absmax - en.absmin) * random() + en.absmin;

	//spawn an explosions somewhere within the bounding box of self.enemy

	T_Damage(en, self, self.owner, 50 * random());

	missile = spawn ();

	missile.movetype = MOVETYPE_NOCLIP;
	missile.solid = SOLID_NOT;
	missile.velocity = '0 0 30';
	missile.touch = SUB_Null;
	setmodel (missile, "progs/s_explod.spr");
	setsize (missile, '0 0 0', '0 0 0');
	setorigin (missile, org);

	en = self;
	self = missile;
	s_explode1 ();
	self = en;


	self.ammo_shells = self.ammo_shells + 1;

	if ((self.ammo_shells > 10) && (self.enemy.health <= 0)) {
		remove(self);
		return;
	}

	if ((self.ammo_shells > 10) && (self.enemy.takedamage != DAMAGE_AIM)) {
		remove(self);
		return;
	}
};

void() T_PoisonTouch;

void() HunterSeekerTouch = {
	local vector org;
	local float r;
	local string s;

	if (other.takedamage) {
/*
                self.movetype = MOVETYPE_NONE;
                self.solid = SOLID_NOT;
		self.enemy = other;

		self.nextthink = time + 0.1;
		self.think = HunterSeekerAttack;

		self.velocity = '0 0 0';
		self.ammo_shells = 0;  //counter

		org = (other.absmax + other.absmin) * 0.5;
		org_z = other.absmin_z + 5;
*/
                T_PoisonTouch();

		setmodel(self, string_null);
		setsize(self, '0 0 0', '0 0 0');
		setorigin(self, org);
		return;
	}

	r = random()*6;

	if (r <= 1)      s = "player/pain1.wav";
	else if (r <= 2) s = "player/pain2.wav";
	else if (r <= 3) s = "player/pain3.wav";
	else if (r <= 4) s = "player/pain4.wav";
	else if (r <= 5) s = "player/pain5.wav";
	else if (r <= 6) s = "player/pain6.wav";

	sound (self, CHAN_WEAPON, s, 1, ATTN_NORM);
};

void() HunterSeekerDie;

void() HunterSeekerSeek = {
	local vector destl;

	self.nextthink = time + 0.1;
	self.flags = self.flags - (self.flags & FL_ONGROUND);

	if (self.enemy.health <= 0 || self.enemy.takedamage == DAMAGE_NO) {
		if (self.owner.health < 0) {
			//if no enemy to seek and no owner to return to..

			self.nextthink = time + 10;
			self.think = SUB_Remove;
		} else {
			self.think = SUB_Null;
			self.touch = HunterSeekerDie;
			self.movetype = MOVETYPE_BOUNCE;
		}

		return;
	}

	destl = (self.enemy.absmax + self.enemy.absmin) * 0.5;

	self.velocity = 500 * normalize(self.velocity + destl - self.origin);

	self.ammo_shells = self.ammo_shells + 1;

	if (self.ammo_shells > 50) {
		self.nextthink = time + 1;
		self.think = SUB_Remove;
	}

};

void(string gibname, float dm) ThrowGib;

void() HunterSeekerDie = {
	local   float   c, d;

	c = 0;

//THROW GIBS HERE

	remove(self);
};

void() W_FireHunterSeeker = {

	local entity missile;
	local float theta;
	local vector angle;
	local vector org, destl;

	self.attack_finished = time + 0.8;
	
	self.punchangle_x = -2;

	if (self.rune_burst_count) {
		if (self.hsa.enemy.takedamage == DAMAGE_AIM) {
                        if (random() <= 0.10) {
				t_damage_kill = 1;
				T_Damage(self.hsa.enemy, self, self, 50000);
				return;
			}
		}
	}

	missile = spawn ();
	missile.owner = self;
	missile.movetype = MOVETYPE_FLYMISSILE;
	missile.solid = SOLID_BBOX;
	missile.classname = "hunter_seeker";

	missile.hsa = self.hsa;

	if (self.hsa.enemy) {
		destl = (self.hsa.enemy.absmax + self.hsa.enemy.absmin) * 0.5;

		missile.enemy = self.hsa.enemy;

		missile.nextthink = time + 0.1;
		missile.think = HunterSeekerSeek;

		missile.touch = HunterSeekerTouch;
	}
	else
	{
		missile.movetype = MOVETYPE_BOUNCE;
		missile.touch = HunterSeekerDie;
	}


// set missile speed

	//counter 'til death
	missile.ammo_shells = 0;

	Biggun_Aim (self.v_angle);

	missile.velocity = v_forward * 500;
	missile.angles = vectoangles(missile.velocity);

	setmodel (missile, "progs/h_player.mdl");
	setsize (missile, '0 0 0', '0 0 0');     
	setorigin (missile, self.origin + v_forward*16 + '0 0 16');
};

// ************************** BURLY NAILGUN ************************** 


void() W_BurlyNailgunThink =
{
	local vector crv, dest_vel;
	local float lerp_coeff;
	local vector del, dest_org;

	self.nextthink = time + 0.1;
	self.ammo_shells = self.ammo_shells + 1;

	if (self.ammo_shells > 100)
	{
		self.think = SUB_Remove;
		return;
	}

	if (self.enemy.health <= 0) self.enemy = world;

	if (self.enemy == world)
	{
		if (self.hsa)
		{
			if (self.hsa.enemy) self.enemy = self.hsa.enemy;
			else return;
		}
		else
		{
			return;
		}
	}

	dest_org = (self.enemy.absmax + self.enemy.absmin) * 0.5;

	del = dest_org - self.origin;

	crv = normalize(del);
	self.velocity = normalize(self.velocity);

//LERP it over...

	// if vlen(del) == 0, then lerp_coeff = 1
	// if vlen(del) -> inf, lerp_coeff -> 0

	lerp_coeff = 1.0 / (1.0 + vlen(del) * 0.01);

	dest_vel = crv - self.velocity;
	dest_vel = dest_vel * lerp_coeff;
	dest_vel = self.velocity + dest_vel;
	dest_vel = normalize(dest_vel);
	

	self.velocity = dest_vel * 500 * (random() + 1.0);

	self.angles = vectoangles(self.velocity);
};

void() W_FireBurlyNailgun =
{
	local entity missile;
	local vector angle;
	local vector org;

	self.attack_finished = time + 0.1;

	sound (self, CHAN_WEAPON, "weapons/spike2.wav", 1, ATTN_NORM);

	self.punchangle_x = -2;

	missile = spawn ();
	missile.owner = self;
	missile.movetype = MOVETYPE_FLYMISSILE;
	missile.solid = SOLID_BBOX;
	missile.classname = "burlnail";

	missile.hsa = self.hsa;

// set missile speed	

	Biggun_Aim (self.v_angle);

	missile.velocity = v_forward * 500 * (random() + 1.0);
	missile.angles = vectoangles(missile.velocity);
	missile.touch = spike_touch;


// set missile duration
	missile.nextthink = time + 0.1;
	missile.think = W_BurlyNailgunThink;

	setmodel (missile, "progs/spike.mdl");
	setsize (missile, '0 0 0', '0 0 0');     
	setorigin (missile, self.origin + v_forward*16 + '0 0 16');
};

// ************************** POISON DART GUN ************************** 

void() PoisonTouchedThink =
{
	local vector vrand;
	local entity temp;

	self.nextthink = time + random();

	t_damage_type = AT_POISON;
	T_Damage(self.enemy, self, self.owner, 3);

        if (    (self.enemy == world) ||
                (self.enemy.health <= 0))
        {
		remove(self);
		return;
	}


	if (self.movetype == MOVETYPE_WALK || self.movetype == MOVETYPE_STEP) {

		vrand_x = crandom() * 200;
		vrand_y = crandom() * 200;
		vrand_z = 50 * (1 + random());
		//make 'em hop
		self.enemy.flags = self.enemy.flags - (self.enemy.flags & FL_ONGROUND);
		self.enemy.velocity = self.enemy.velocity * 0.5 + vrand;
	}

	if (self.classname == "player") {

		vrand_x = crandom() * 200;
		vrand_y = crandom() * 200;
		vrand_z = crandom() * 200;

		vrand = vrand + self.enemy.origin;

		temp = msg_entity;
		msg_entity = self.enemy;

		WriteByte (MSG_ONE, SVC_TEMPENTITY);
		WriteByte (MSG_ONE, TE_EXPLOSION);
		WriteCoord (MSG_ONE, vrand_x);
		WriteCoord (MSG_ONE, vrand_y);
		WriteCoord (MSG_ONE, vrand_z);

		msg_entity = temp;
	}
};


void() T_PoisonTouch =
{
	self.enemy = other;

	self.movetype = MOVETYPE_NONE;
	self.solid = SOLID_NOT;
	self.modelindex = 0;

	self.nextthink = time + 0.6;
	self.think = PoisonTouchedThink;

};

void() W_FirePoisonGun = {

	local	entity missile, mpuff;

	self.attack_finished = time + 0.2;
		
	sound (self, CHAN_WEAPON, "weapons/sgun1.wav", 1, ATTN_NORM);

	self.punchangle_x = -2;

	missile = spawn ();
	missile.owner = self;
	missile.movetype = MOVETYPE_FLYMISSILE;
	missile.solid = SOLID_BBOX;
	missile.classname = "poison";
		
// set missile speed	

	Biggun_Aim (self.v_angle);
	missile.velocity = v_forward * 1200 + v_right * 100 * crandom() + v_up * 100 * crandom();
	missile.angles = vectoangles(missile.velocity);

	missile.touch = T_PoisonTouch;
	
// set missile duration
	missile.nextthink = time + 10;
	missile.think = SUB_Remove;

	setmodel (missile, "progs/spike.mdl");
	setsize (missile, '0 0 0', '0 0 0');		
	setorigin (missile, self.origin + v_forward*8 + '0 0 16');
};

// ************************** BIGASS SHOTGUN ************************** 

void() W_FireBigassShotgun = {
	local vector dir;

	self.attack_finished = time + 1.0;

	sound (self ,CHAN_WEAPON, "weapons/shotgn2.wav", 1, ATTN_NORM);	

	self.punchangle_x = -4;
	
	Biggun_Aim(self.v_angle);

	dir = v_forward;

	FireMyBullets (12, dir, '0.10 0.06 0', 48);
};


// ************************** SCREAM CANNON ************************** 

void() W_ScreamCannonThink =
{
	local vector crv;


	self.nextthink = time + 0.1;

	self.ammo_shells = self.ammo_shells - 1;

	if (self.ammo_shells < 0)
	{
		self.think = GrenadeExplode;
		return;
	}

	crv_x = crandom();
	crv_y = crandom();
	crv_z = crandom();

	self.velocity = self.velocity + 50 * crv;
	self.velocity = 500 * normalize(self.velocity);

	self.angles = vectoangles(self.velocity);
};

void() W_FireScreamCannon = {

	local entity missile;
	local float theta;
	local vector angle;
	local vector org;

	self.attack_finished = time + 0.6;

	sound (self, CHAN_WEAPON, "weapons/sgun1.wav", 1, ATTN_NORM);

	self.punchangle_x = -2;


	theta = 0;

	while (theta < 6)
	{

		theta = theta + 1;


		missile = spawn ();
		missile.owner = self;
		missile.movetype = MOVETYPE_FLYMISSILE;
		missile.solid = SOLID_BBOX;
		missile.classname = "scream";

// set missile speed	

		Biggun_Aim (self.v_angle);

		missile.velocity = v_forward * 500;
		missile.angles = vectoangles(missile.velocity);
	
		missile.touch = T_MissileTouch;
	
// set missile duration
		missile.ammo_shells = 100;      //timer to explode
		missile.nextthink = time + 0.1;
		missile.think = W_ScreamCannonThink;

		setmodel (missile, "progs/missile.mdl");
		setsize (missile, '0 0 0', '0 0 0');     
		setorigin (missile, self.origin + v_forward*16 + '0 0 16');
	}
};

// ************************** BLINK CANNON ************************** 

void() T_BlinkThink =
{
	self.nextthink = time + 0.1;

	t_damage_type = AT_EXPLOSION;
	T_RadiusDamage(self, self.owner, 120, self.owner);

	self.ammo_shells = self.ammo_shells - 1;

	if (self.ammo_shells < 0)
	{
		self.think = SUB_Remove;
		return;
	}

	if ((self.ammo_shells & 1) == 1)
		self.effects = self.effects | EF_BRIGHTFIELD;
	else
		self.effects = self.effects - (self.effects & EF_BRIGHTFIELD);
};

void() W_FireBlinkGun = {

	local	entity missile, mpuff;

	self.attack_finished = time + 0.8;
	
	sound (self, CHAN_WEAPON, "weapons/sgun1.wav", 1, ATTN_NORM);

	self.punchangle_x = -2;

	missile = spawn ();
	missile.owner = self;
	missile.movetype = MOVETYPE_FLYMISSILE;
	missile.solid = SOLID_BBOX;
	missile.classname = "blink";
		
// set missile speed	

	Biggun_Aim (self.v_angle);
	missile.velocity = v_forward * 400;
	missile.angles = vectoangles(missile.velocity);
	
	missile.touch = T_MissileTouch;
	
// set missile duration
	missile.ammo_shells = 100;
	missile.nextthink = time + 0.1;
	missile.think = T_BlinkThink;

	setmodel (missile, "progs/missile.mdl");
	setsize (missile, '0 0 0', '0 0 0');		
	setorigin (missile, self.origin + v_forward*8 + '0 0 16');
};

// ************************** THE BIG GUN ************************** 

entity(entity ow, vector org) N_CreateExplosion =
{
	local entity missile;
	local vector src;

	missile = spawn ();
	missile.owner = ow;
	missile.movetype = MOVETYPE_NONE;
	missile.solid = SOLID_NOT;
	missile.classname = "big_boom";

// set missile duration
	missile.nextthink = time + 0.1;
	missile.think = GrenadeExplode;

	setsize (missile, '0 0 0', '0 0 0');     
	setorigin (missile, org);

	src = self.origin;

	WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
	WriteByte (MSG_BROADCAST, TE_LIGHTNING3);
	WriteEntity (MSG_BROADCAST, missile);
	WriteCoord (MSG_BROADCAST, src_x);
	WriteCoord (MSG_BROADCAST, src_y);
	WriteCoord (MSG_BROADCAST, src_z);
	WriteCoord (MSG_BROADCAST, org_x);
	WriteCoord (MSG_BROADCAST, org_y);
	WriteCoord (MSG_BROADCAST, org_z);


	return missile;
};


void() W_FireBigGun = {

	local   vector  dir, src, spread, direction;
	local   float   bul_count;
	local   entity  missile;

	self.attack_finished = time + 0.1;

	Biggun_Aim(self.v_angle);

	src = self.origin + v_forward*10;
	src_z = self.absmin_z + self.size_z * 0.7;

	spread =  '0.1 0.1 0';

	bul_count = 5;

	dir = v_forward;

	while (bul_count > 0) {
		bul_count = bul_count - 1;
		direction = dir + crandom()*spread_x*v_right + crandom()*spread_y*v_up;

		traceline (src, src + direction*2048, FALSE, self);

		if (trace_ent.takedamage)
		{
			//for the sake of switches
			t_damage_type = AT_EXPLOSION;
			T_Damage(trace_ent, self, self, 1);
		}


		missile = N_CreateExplosion(self, trace_endpos);
		missile.nextthink = time + 2.0 * random();
	}
};

// ************************** SQUIDGY BOMB ************************** 

void() SquidgyExplode =
{
	local entity head, poison;
	local float cont;
	local vector org;

	head = findradius(self.origin, 120);

	while (head)
	{
		cont = TRUE;

		if (head == world) cont = FALSE;
		if (head == self) cont = FALSE;
		if (head == self.owner) cont = FALSE;
		if (head.health <= 0) cont = FALSE;
		if (head.takedamage == DAMAGE_NO) cont = FALSE;
		if ((teamplay == 1) && (head.team == self.team)) cont = FALSE;

		if (cont)
		{
			org = (head.absmax + head.absmin) * 0.5;
			traceline(self.origin, org, FALSE, self);
			if ((trace_fraction == 1.0) || (trace_ent == head))
			{
				poison = spawn();
				poison.enemy = head;
				poison.owner = self.owner;
				poison.nextthink = time + 0.6;
				poison.think = PoisonTouchedThink;
			}
		}

		head = head.chain;
	}

	remove(self);
};

void() SquidgyBombFly =
{
	self.nextthink = time + 0.1;

	self.ammo_nails = self.ammo_nails - 1;
	if (self.ammo_nails < 0)
	{
		//do the explosion
		SquidgyExplode();
		return;
	}

	if (self.ammo_shells == 1)
	{
		self.ammo_shells = 2;
		return;
	}

	if (self.ammo_shells == 2)
	{
		self.movetype = MOVETYPE_FLYMISSILE;

		if (self.velocity == '0 0 0')
		{
			SquidgyExplode();
			return;
		}

		self.velocity = normalize(self.velocity) * 900;
		self.velocity_z = self.velocity_z + 100;

		self.ammo_shells = 0;

		return;
	}

};
void() SquidgyBombTouch =
{
	//only detonate after first bounce
	if (other.takedamage == DAMAGE_AIM)
	{
		SquidgyExplode();
		return;
	}

	sound (self, CHAN_WEAPON, "weapons/bounce.wav", 1, ATTN_NORM);	// bounce sound

	self.movetype = MOVETYPE_BOUNCE;

	//notifier that movetype needs to be reset
	self.ammo_shells = 1;
};       

void() W_FireSquidgyBomb = {
	local	entity missile, mpuff;
	
	self.attack_finished = time + 0.6;

	sound (self, CHAN_WEAPON, "weapons/grenade.wav", 1, ATTN_NORM);

	self.punchangle_x = -2;

	missile = spawn ();
	missile.owner = self;
	missile.movetype = MOVETYPE_FLYMISSILE;
	missile.solid = SOLID_BBOX;
	missile.classname = "squidgybomb";

	Biggun_Aim (self.v_angle);

	missile.velocity = v_forward * 900;
	missile.avelocity = '300 300 300';
	missile.angles = vectoangles(missile.velocity);

	missile.touch = SquidgyBombTouch;
	setmodel (missile, "progs/grenade.mdl");
	setsize (missile, '0 0 0', '0 0 0');		
	setorigin (missile, self.origin);

	//notifier that movetype needs to be reset
	missile.ammo_shells = 0;
	//timer to explosion
	missile.ammo_nails = 100;

	missile.nextthink = time + 0.1;
	missile.think = SquidgyBombFly;
};

// ************************** SOS GUN ************************** 

void() SOS_Touch = {
	if ((other.takedamage == DAMAGE_AIM) &&
		(other.health > 0) &&
		(other.classname != "monster_smite"))
	{
		bring_on_the_smite(other);
		remove(self);
	}
};

void() W_FireSOS = {
	local	entity missile, mpuff;
	
	if (!self.rune_burst_count) {
		self.attack_finished = time + 1;
	} else {
		self.attack_finished = time + 0.4;
	}

	sound (self, CHAN_WEAPON, "weapons/grenade.wav", 1, ATTN_NORM);

	self.punchangle_x = -2;

	missile = spawn ();
	missile.owner = self;
	missile.movetype = MOVETYPE_BOUNCE;
	missile.solid = SOLID_BBOX;
	missile.classname = "grenade";
		
// set missile speed	

	Biggun_Aim (self.v_angle);

	missile.velocity = v_forward*600 + v_up * 200 + crandom() * v_right * 10 + crandom() * v_up * 10;

	missile.avelocity = '300 300 300';

	missile.angles = vectoangles(missile.velocity);
	
	missile.touch = SOS_Touch;
	
// set missile duration
	missile.nextthink = time + 2.5;
	missile.think = SUB_Remove;

	setmodel (missile, "progs/grenade.mdl");
	setsize (missile, '0 0 0', '0 0 0');		
	setorigin (missile, self.origin);
};

// ************************** DISASTER ************************** 

void(vector org) spawn_tfog;
void(vector org, entity e) spawn_tdeath;

void() Disaster_Touch = {
	local float rand;
	local entity stemp;
        local vector lastpos, newpos;
        local float tries;

	if (other.solid == SOLID_TRIGGER)
		return;	// trigger field, do nothing

// hit something that bleeds
	if (other.takedamage == DAMAGE_NO)      //wall
	{
		WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
		WriteByte (MSG_BROADCAST, TE_SPIKE);
		WriteCoord (MSG_BROADCAST, self.origin_x);
		WriteCoord (MSG_BROADCAST, self.origin_y);
		WriteCoord (MSG_BROADCAST, self.origin_z);
	}
	else    //shootable trigger / creature
	{
		//change the weapon before applying the damage
		//if we apply damage first then we risk killing him
		//before switching weapons - and if we switch weapons
		//on a dead man then that will mess up their respawn
                if (other.classname == "player") {
			stemp = self;
			self = other;
			SetMyWeapon(random() * BIG_GUN_MAX);

                        //pop out a rune?
                        if (self.rune_vampire_count) self.rune_vampire_count = self.rune_vampire_count - 1;
                        if (self.rune_autoaim_count) self.rune_autoaim_count = self.rune_autoaim_count - 1;
                        if (self.rune_thorns_count) self.rune_thorns_count = self.rune_thorns_count - 1;
                        if (self.rune_armor_count) self.rune_armor_count = self.rune_armor_count - 1;
                        if (self.rune_quad_count) self.rune_quad_count = self.rune_quad_count - 1;
                        if (self.rune_burst_count) self.rune_burst_count = self.rune_burst_count - 1;
                        if (self.rune_regen_count) self.rune_regen_count = self.rune_regen_count - 1;
                        if (self.rune_invis_count) self.rune_invis_count = self.rune_invis_count - 1;
                        if (self.rune_freeze_count) self.rune_freeze_count = self.rune_freeze_count - 1;
                        if (self.rune_revenge_count) self.rune_revenge_count = self.rune_revenge_count - 1;

			W_SetCurrentAmmo ();

                        //now teleport the guy a bit
                        //first store his old position
                        //then give him a new random one
                        //droptofloor him
                        //if it fails then put him back

                        tries = 25;
                        while (tries > 0) {
                                tries = tries - 1;

                                lastpos = self.origin;
                                newpos_x = lastpos_x + crandom() * 2048;
                                newpos_y = lastpos_y + crandom() * 2048;
                                newpos_z = lastpos_z + crandom() * 2048;
                                setorigin(self, newpos);
                                if (!droptofloor()) {
                                        setorigin(self, lastpos);
                                } else {
                                        spawn_tfog(lastpos);
                                        spawn_tdeath(lastpos, self);
                                        break;
                                }
                        }
                        
			self = stemp;
		}

		spawn_touchblood (9);
		t_damage_type = AT_NAILS;
                T_Damage (other, self, self.owner, 10 + random() * 20);
	}

	remove(self);

};

void() W_FireDisaster = {
	local entity missile;
	local vector angle;
	local vector org;

	self.attack_finished = time + 0.2;

	sound (self, CHAN_WEAPON, "weapons/spike2.wav", 1, ATTN_NORM);

	self.punchangle_x = -2;

	missile = spawn ();
	missile.owner = self;
	missile.movetype = MOVETYPE_FLYMISSILE;
	missile.solid = SOLID_BBOX;
	missile.classname = "disaster";

	missile.hsa = self.hsa;

// set missile speed	

	Biggun_Aim (self.v_angle);

	missile.velocity = v_forward * 700;
	missile.angles = vectoangles(missile.velocity);
	missile.touch = Disaster_Touch;


// set missile duration
	missile.nextthink = time + 10;
	missile.think = SUB_Remove;

	setmodel (missile, "progs/spike.mdl");
	setsize (missile, '0 0 0', '0 0 0');     
	setorigin (missile, self.origin + v_forward*16 + '0 0 16');
};

// ************************** LAZER ************************** 


void() LazerFire = {

	local	vector	vec, org, dst;
	local	float	dot;

	self.nextthink = time + 0.1;

	org = self.origin;
	dst = org + self.angles * 2048;

	traceline (org, dst, FALSE, self.owner);

	if (trace_fraction == 1.0) {
		remove(self);
		return;
	}

	dst = trace_endpos - self.angles*4;
	setorigin(self, dst);	//push away from wall


	if (random() < 0.05) {
		WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
		WriteByte (MSG_BROADCAST, TE_LIGHTNING1);
		WriteEntity (MSG_BROADCAST, self);
		WriteCoord (MSG_BROADCAST, org_x);
		WriteCoord (MSG_BROADCAST, org_y);
		WriteCoord (MSG_BROADCAST, org_z);
		WriteCoord (MSG_BROADCAST, dst_x);
		WriteCoord (MSG_BROADCAST, dst_y);
		WriteCoord (MSG_BROADCAST, dst_z);
	}

//	dot = 1;
//	while (dot > 0) {
//		vec = (dst - org) * dot + org;
//		particle (vec, -100 * self.angles, 107, 50);
//		dot = dot - 0.075;
//	}

	particle (dst, -100 * self.angles, 107, 50);

	//preserve the new forward direction
	//reflect by trace_plane_normal
	//	v - 2n(v.n)
	dot = trace_plane_normal * self.angles;
	self.angles = self.angles - 2 * dot * trace_plane_normal;
	self.angles = normalize(self.angles);

	if (trace_ent.takedamage) {
		t_damage_type = AT_LIGHTNING;
		T_Damage (trace_ent, self, self.owner, 24);
		remove(self);
		return;
	}

	self.ammo_shells = self.ammo_shells - 1;
	if (self.ammo_shells <= 0) {
		remove(self);
		return;
	}
};

void() W_FireLazer = {
	local	entity	bullet, stemp;

	self.attack_finished = time + 0.2;

	sound (self, CHAN_WEAPON, "weapons/ric1.wav", 1, ATTN_NORM); 

	self.punchangle_x = -2;
	bullet = spawn ();
	bullet.owner = self;
	bullet.movetype = MOVETYPE_NONE;
	bullet.solid = SOLID_NOT;
	bullet.classname = "lazer_shot";
	bullet.think = LazerFire;
	bullet.ammo_shells = 20;

	Biggun_Aim(self.v_angle);
	bullet.angles = v_forward;

	setorigin(bullet, self.origin + '0 0 16');

	stemp = self;
	self = bullet;

	//execute the first fire routine
	LazerFire();

	self = stemp;
};

// ************************** HOLY STRIKER ************************** 


//void() W_FireHolyStriker = {
//
//};

// ************************** SECRET SHOT ************************** 

//void() W_FireSecretShot = {
//
//};

/*
===============================================================================

PLAYER WEAPON USE

===============================================================================
*/

void() W_SetCurrentAmmo =
{
	player_run ();		// get out of any weapon firing states

	self.items = self.items - ( self.items & (IT_SHELLS | IT_NAILS | IT_ROCKETS | IT_CELLS) );
	
//	self.currentammo = 0;
	self.weaponframe = 0;

	self.weaponmodel = self.player_weapon_model;

};

float() W_BestWeapon =
{
	return IT_SHOTGUN;
};

float() W_CheckNoAmmo =
{
	return TRUE;	    //always have ammo
};

/*
============
W_Attack

An attack impulse can be triggered now
============
*/
void()  player_axe_start;
void()	player_shot1;
void()	player_nail1;
void()	player_light1;
void()	player_rocket1;

void() W_Attack = {

	local	float	r;

	//currentammo is bad sauce
	//if we're doing a single player game
	//if (!coop && !deathmatch)
	//if (self.currentammo == 0) return;


	Biggun_Aim (self.v_angle);		 // calculate forward angle for velocity

	if (self.rune_invis_count == 0) {
		self.show_hostile = time + 1;	// wake monsters up
	} else {
		self.show_hostile = time + 10 * (1 - self.rune_invis_count / (self.rune_invis_count + 3));
	}


//	if (self.rune_burst_count > 0) {
//		r = self.player_burst_count;
//		while (r > 0) {
//			player_shot1();
//			r = r - 1;
//		}
//		self.attack_finished = time + self.player_burst_delay;
//	} else {
//		self.attack_finished = time + self.player_attack_delay;
		self.player_attack_frame();
//	}


	//currentammo is bad sauce
	//if we're doing a single player game
	//if (!coop && !deathmatch)
	//self.currentammo = self.currentammo - 1;

};


void(float dir) SelWeapon =
{
	if (deathmatch || coop)
		return;

	self.lip = self.lip + dir;
	if (self.lip > BIG_GUN_MAX) self.lip = 1;
	if (self.lip < 1) self.lip = BIG_GUN_MAX;

	SetMyWeapon(self.lip);

	sprint (self, "You got the ");
	sprint (self, self.player_weapon_name);
	sprint (self, "\n");
	
	W_SetCurrentAmmo();
};      

/*
============
CheatCommand
============
*/
void() CheatCommand =
{
	if (deathmatch || coop)
		return;

	self.ammo_rockets = 100;
	self.ammo_nails = 200;
	self.ammo_shells = 100;

	self.impulse = 0;
	W_SetCurrentAmmo ();
};


/*
============
ServerflagsCommand

Just for development
============
*/
void() ServerflagsCommand =
{
	serverflags = serverflags * 2 + 1;
};

void() QuadCheat =
{
	if (deathmatch || coop)
		return;
	self.super_time = 1;
	self.super_damage_finished = time + 30;
	self.items = self.items | IT_QUAD;

	dprint ("quad cheat\n");
};

void() RuneCheat = {
	if (deathmatch || coop)
		return;
	self.rune_vampire_count = self.rune_vampire_count + 1;
	self.rune_autoaim_count = self.rune_autoaim_count + 1;
	self.rune_thorns_count = self.rune_thorns_count + 1;
	self.rune_armor_count = self.rune_armor_count + 1;
	self.rune_quad_count = self.rune_quad_count + 1;
	self.rune_burst_count = self.rune_burst_count + 1;
	self.rune_regen_count = self.rune_regen_count + 1;
	self.rune_invis_count = self.rune_invis_count + 1;
	self.rune_freeze_count = self.rune_freeze_count + 1;
	self.rune_revenge_count = self.rune_revenge_count + 1;
	sprint (self, "rune cheat!\n");
};

/*
============
ImpulseCommands

============
*/
void(entity smitten) bring_on_the_smite;

void() ImpulseCommands =
{
//my addition... 
	self.get_button = 0;
	if ((self.impulse == 10) || (self.impulse == 12))
		self.get_button = 1;

	if (self.impulse == 9)
		CheatCommand ();
	if (self.impulse == 11)
		ServerflagsCommand ();

	if (self.impulse == 20) SelWeapon(1);
	if (self.impulse == 21) SelWeapon(-1);


	if (self.impulse == 254)		RuneCheat ();
	if (self.impulse == 255)		QuadCheat ();

	if (self.impulse == 200) bring_on_the_smite(self);
		
	self.impulse = 0;
};

/*
============
W_WeaponFrame

Called every frame so impulse events can be handled as well as possible
============
*/
void() W_WeaponFrame = {
	CheckGrapHook();

//my addition... the Hunter Seeker Algorithm (excuse the Alpha Centauri ripoff)
	if (self.hsa == world) CreateHSA();

	ImpulseCommands ();
	
	if (time < self.attack_finished)
		return;

// check for attack
	if (self.next_attack_time > time) return;

	if (self.button0) {
		SuperDamageSound ();
		W_Attack ();
	}
};

/*
========
SuperDamageSound

Plays sound if needed
========
*/
void() SuperDamageSound = {
	if (self.super_damage_finished > time) {
		if (self.super_sound < time) {
			self.super_sound = time + 1;
			sound (self, CHAN_BODY, "items/damage3.wav", 1, ATTN_NORM);
		}
	}
	return;
};


