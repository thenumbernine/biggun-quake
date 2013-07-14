
void() T_MissileTouch;
void() info_player_start;
void(entity targ, entity attacker) ClientObituary;

void() monster_death_use;

//============================================================================

/*
============
CanDamage

Returns true if the inflictor can directly damage the target.  Used for
explosions and melee attacks.
============
*/
float(entity targ, entity inflictor) CanDamage =
{
// bmodels need special checking because their origin is 0,0,0
	if (targ.movetype == MOVETYPE_PUSH)
	{
		traceline(inflictor.origin, 0.5 * (targ.absmin + targ.absmax), TRUE, self);
		if (trace_fraction == 1)
			return TRUE;
		if (trace_ent == targ)
			return TRUE;
		return FALSE;
	}
	
	traceline(inflictor.origin, targ.origin, TRUE, self);
	if (trace_fraction == 1)
		return TRUE;
	traceline(inflictor.origin, targ.origin + '15 15 0', TRUE, self);
	if (trace_fraction == 1)
		return TRUE;
	traceline(inflictor.origin, targ.origin + '-15 -15 0', TRUE, self);
	if (trace_fraction == 1)
		return TRUE;
	traceline(inflictor.origin, targ.origin + '-15 15 0', TRUE, self);
	if (trace_fraction == 1)
		return TRUE;
	traceline(inflictor.origin, targ.origin + '15 -15 0', TRUE, self);
	if (trace_fraction == 1)
		return TRUE;

	return FALSE;
};


//my respawn mod
void() monster_die;

/*
============
Killed
============
*/
void(entity targ, entity attacker) Killed =
{
	local entity oself;

	oself = self;
	self = targ;
	
	if (self.health < -99)
		self.health = -99;		// don't let sbar look bad if a player

	if (self.movetype == MOVETYPE_PUSH || self.movetype == MOVETYPE_NONE)
	{	// doors, triggers, etc

		self.th_die ();
		self = oself;
		return;
	}

	self.enemy = attacker;

	//reset the live frags - prevent the smite from coming unwanted
	self.live_frags = 0;

// bump the monster counter
	if (self.flags & FL_MONSTER) {
		killed_monsters = killed_monsters + 1;
		WriteByte (MSG_ALL, SVC_KILLEDMONSTER);
	}

	ClientObituary(self, attacker);
	
	self.takedamage = DAMAGE_NO;
	self.touch = SUB_Null;

	monster_death_use();

	//do respawn... ifyou have the guts
	if (self.flags & FL_MONSTER) {
		monster_die();
	}

	self.th_die ();
	
	self = oself;
};



//********* DAMAGE-DELAYS - USED FOR THORNS ********* 

void(entity targ, entity inflictor, entity attacker, float damage) T_Damage;

float thorns_damage;

void() SpawnDamageDeal =
{
	thorns_damage = 1;
	T_Damage(self.enemy, self.owner, self.owner, self.dmg);
	remove(self);
};

void(entity targ, entity inflictor, float damage) SpawnDamager =
{
	local   entity  e;

	e = spawn();

	e.enemy = targ;
	e.owner = inflictor;
	e.dmg = damage;

	e.nextthink = time + 0.1;
	e.think = SpawnDamageDeal;
};

float(entity e, float d) QuadRuneDamage = {
	return d * (16 * e.rune_quad_count / (e.rune_quad_count + 15) + 1);
};

entity damage_inflictor;

/*
============
T_Damage

The damage is coming from inflictor, but get mad at attacker
This should be the only function that ever reduces health.
============
*/
void(entity targ, entity inflictor, entity attacker, float damage) T_Damage=
{
	local	vector	dir;
	local	entity	oldself;
	local	float	save;
	local	float	take;
	local   float   thorns_dmg, dmg_kill, dmg_type;

	dmg_kill = t_damage_kill;
	dmg_type = t_damage_type;
	thorns_dmg = thorns_damage;

	t_damage_kill = 0;
	t_damage_type = 0;
	thorns_damage = 0;

// dont even consider damage towards teammates
	if ((teamplay == 1) &&
	    (targ.team > 0) &&
	    (targ.team == attacker.team) &&
	    (targ != attacker) &&
	    (dmg_kill == 0))
	{
		return;
	}

	if ((teamplay == 1) && (dmg_kill == 2)) return;

	damage_inflictor = inflictor;

	if (!targ.takedamage)
	{
		return;
	}

// used by buttons and triggers to set activator for target firing
	damage_attacker = attacker;

// check for quad damage powerup on the attacker
	if (attacker.super_damage_finished > time)
		damage = damage * 4;

//RUNE ADDITION - quad rune
	if (attacker.rune_quad_count > 0) {
		damage = QuadRuneDamage(attacker, damage);
	}

// save damage based on the target's armor level

//MY MOD - altering armortype
	if ((dmg_type) && (targ.armortype == dmg_type))
	{
		damage = damage * 0.75;
		sound (targ, CHAN_ITEM, "misc/medkey.wav", 1, ATTN_NORM);
	}

	save = ceil(damage);
	if (save >= targ.armorvalue)
	{
		save = targ.armorvalue;
		targ.armortype = 0;	// lost all armor
		targ.items = targ.items - (targ.items & (IT_ARMOR1 | IT_ARMOR2 | IT_ARMOR3));
	}

//RUNE ADDITION - armor rune
	if (targ.rune_armor_count > 0) {
		take = ceil(take * (1 - 0.1 * targ.rune_armor_count / (targ.rune_armor_count + 1)));
	}

    take = damage;
    save = damage;

// add to the damage total for clients, which will be sent as a single
// message at the end of the frame
// FIXME: remove after combining shotgun blasts?
	if (targ.flags & FL_CLIENT)
	{
		targ.dmg_take = targ.dmg_take + take;
		targ.dmg_save = targ.dmg_save + save;
		targ.dmg_inflictor = inflictor;
	}

// figure momentum add
	if ( (inflictor != world) && (targ.movetype == MOVETYPE_WALK) )
	{
		dir = targ.origin - (inflictor.absmin + inflictor.absmax) * 0.5;
		dir = normalize(dir);
		targ.velocity = targ.velocity + dir*damage*8;
	}

// check for godmode or invincibility
	if (targ.flags & FL_GODMODE)
	{
		return;
	}

	if ((targ.invincible_finished >= time) &&
		(dmg_kill == 0))
	{
		if (self.invincible_sound < time)
		{
			sound (targ, CHAN_ITEM, "items/protect3.wav", 1, ATTN_NORM);
			self.invincible_sound = time + 2;
		}

		return;
	}

// team play damage avoidance
	if ((teamplay == 1) &&
	    (targ.team > 0) &&
	    (targ.team == attacker.team) &&
	    (dmg_kill == 0))
	{
		return;
	}

//RUNE ADDITION - revenge rune
	if ((attacker != targ) &&
		(attacker.takedamage == DAMAGE_AIM))
	{
		targ.revenge_ent = attacker;
	} else {
		targ.revenge_ent = world;
	}
		
// do the damage
	targ.health = targ.health - take;

//RUNE ADDITION - vampire rune
	if ((attacker.rune_vampire_count > 0) &&
		(attacker != targ) &&
	    (targ.takedamage == DAMAGE_AIM) &&
		(attacker.deadflag == DEAD_NO) &&
	    ((attacker.my_flags & MY_GORED) == 0))
	{
		attacker.health = attacker.health + take * 8.0 * attacker.rune_vampire_count / (attacker.rune_vampire_count + 15);
		if (attacker.health > 999)
			attacker.health = 999;
	}

//RUNE ADDITION - thorns
	if ((targ.rune_thorns_count > 0) &&
		(attacker != targ) &&
		(attacker.takedamage) &&
		!(thorns_dmg))
	{
		SpawnDamager(attacker, targ, 8 * take * targ.rune_thorns_count / (targ.rune_thorns_count + 15));
	}

	if (targ.health <= 0)
	{
		Killed (targ, attacker);
		return;
	}

// react to the damage
	oldself = self;
	self = targ;

	if ( (self.flags & FL_MONSTER) && attacker != world)
	{
	// get mad unless of the same class (except for soldiers)
		if (self != attacker && attacker != self.enemy)
		{
			if ( (self.classname != attacker.classname) 
			|| (self.classname == "monster_army" ) )
			{
				if (self.enemy.classname == "player")
					self.oldenemy = self.enemy;
				self.enemy = attacker;
				FoundTarget ();
			}
		}
	}

	if (self.th_pain)
	{
		self.th_pain (attacker, take);
	// nightmare mode monsters don't go into pain frames often
		if (skill == 3)
			self.pain_finished = time + 5;		
	}

	self = oldself;
};

/*
============
T_RadiusDamage
============
*/
void(entity inflictor, entity attacker, float damage, entity ignore) T_RadiusDamage =
{
	local   float   points, damage, rad, init_dmg;
	local	entity	head;
	local	vector	org;

	local   float   thorns_dmg, dmg_kill, dmg_type;

	dmg_kill = t_damage_kill;
	dmg_type = t_damage_type;
	thorns_dmg = thorns_damage;

	init_dmg = damage;
	rad = damage;

// check for quad damage powerup on the attacker
	if (attacker.super_damage_finished > time)
		rad = rad * 1.5;

//RUNE ADDITION
	if (attacker.rune_quad_count > 0) {
                rad = rad + rad * 8 * attacker.rune_quad_count / (attacker.rune_quad_count + 15);
	}

	rad = rad + 40;

	head = findradius(inflictor.origin, rad);
	
	while (head) {
                if (head != ignore) {
			if (head.takedamage) {
				org = head.origin + (head.mins + head.maxs)*0.5;
				points = 0.5*vlen (inflictor.origin - org);
				if (points < 0)
					points = 0;
				points = rad - points;

				if (head == attacker)
					points = points * 0.5;

                                //special case for cluster bomb
                                if (inflictor.classname == "napalm" &&
                                        head == inflictor.owner)
                                {
                                        points = points * 0.25;
                                }

				if (points > 0) {
					if (CanDamage (head, inflictor)) {
						// shambler takes half damage from all explosions
						damage = points * init_dmg / rad;
						if (head.classname == "monster_shambler")				
							damage = damage * 0.5;

						t_damage_kill = dmg_kill;
						t_damage_type = dmg_type;
						thorns_damage = thorns_dmg;

						T_Damage (head, inflictor, attacker, damage);
					}
				}
			}
		}
		head = head.chain;
	}
};

/*
============
T_BeamDamage
============
*/
void(entity attacker, float damage) T_BeamDamage =
{
	local	float 	points;
	local	entity	head;
	
	head = findradius(attacker.origin, damage+40);
	
	while (head)
	{
		if (head.takedamage)
		{
			points = 0.5*vlen (attacker.origin - head.origin);
			if (points < 0)
				points = 0;
			points = damage - points;
			if (head == attacker)
				points = points * 0.5;
			if (points > 0)
			{
				if (CanDamage (head, attacker))
				{
					if (head.classname == "monster_shambler")						
						T_Damage (head, attacker, attacker, points*0.5);
					else
						T_Damage (head, attacker, attacker, points);
				}
			}
		}
		head = head.chain;
	}
};

