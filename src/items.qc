
void() W_SetCurrentAmmo;

/* ALL LIGHTS SHOULD BE 0 1 0 IN COLOR ALL OTHER ITEMS SHOULD
BE .8 .3 .4 IN COLOR */


void() SUB_regen = {

	self.model = self.mdl;		// restore original model
	self.solid = SOLID_TRIGGER;	// allow it to be touched again
	sound (self, CHAN_VOICE, "items/itembk2.wav", 1, ATTN_NORM);	// play respawn sound
	setorigin (self, self.origin);
};



/*QUAKED noclass (0 0 0) (-8 -8 -8) (8 8 8)
prints a warning message when spawned
*/
void() noclass = {

	dprint ("noclass spawned at");
	dprint (vtos(self.origin));
	dprint ("\n");
	remove (self);
};



/*
============
PlaceItem

plants the object on the floor
============
*/
void() PlaceItem = {

	local float	oldz;

	self.mdl = self.model;		// so it can be restored on respawn
	self.flags = FL_ITEM;		// make extra wide
	self.solid = SOLID_TRIGGER;
	self.movetype = MOVETYPE_TOSS;	
	self.velocity = '0 0 0';
	self.origin_z = self.origin_z + 6;
	oldz = self.origin_z;
	if (!droptofloor())
	{
		dprint ("Bonus item fell out of level at ");
		dprint (vtos(self.origin));
		dprint ("\n");
		remove(self);
		return;
	}
};

/*
============
StartItem

Sets the clipping size and plants the object on the floor
============
*/
void() StartItem =
{
	self.nextthink = time + 0.2;	// items start after other solids
	self.think = PlaceItem;
};

/*
=========================================================================

HEALTH BOX

=========================================================================
*/

float player_max_health = 999;
float player_min_health = 25;

//
// T_Heal: add health to an entity, limiting health to max_health
// "ignore" will ignore max_health limit
//
float (entity e, float healamount, float ignore) T_Heal =
{
	if (e.health <= 0)
		return 0;
	if ((!ignore) && (e.health >= other.max_health))
		return 0;
	if (e.my_flags & MY_GORED)
		return 0;

	healamount = ceil(healamount);

	e.health = e.health + healamount;
	if ((!ignore) && (e.health >= other.max_health))
		e.health = other.max_health;
		
	if (e.health > player_max_health)
		e.health = player_max_health;
	return 1;
};

/*QUAKED item_health (.3 .3 1) (0 0 0) (32 32 32) rotten megahealth
Health box. Normally gives 25 points.
Rotten box heals 5-10 points,
megahealth will add 100 health, then 
rot you down to your maximum health limit, 
one point per second.
*/

float	H_ROTTEN = 1;
float	H_MEGA = 2;
.float	healamount, healtype;
void() health_touch;
void() item_megahealth_rot;

void() item_health =
{	
	self.touch = health_touch;

	if (self.spawnflags & H_ROTTEN)
	{
		precache_model("maps/b_bh10.bsp");

		precache_sound("items/r_item1.wav");
		setmodel(self, "maps/b_bh10.bsp");
		self.noise = "items/r_item1.wav";
		self.healamount = 15;
		self.healtype = 0;
	}
	else
	if (self.spawnflags & H_MEGA)
	{
		precache_model("maps/b_bh100.bsp");
		precache_sound("items/r_item2.wav");
		setmodel(self, "maps/b_bh100.bsp");
		self.noise = "items/r_item2.wav";
		self.healamount = 100;
		self.healtype = 2;
	}
	else
	{
		precache_model("maps/b_bh25.bsp");
		precache_sound("items/health1.wav");
		setmodel(self, "maps/b_bh25.bsp");
		self.noise = "items/health1.wav";
		self.healamount = 25;
		self.healtype = 1;
	}
	setsize (self, '0 0 0', '32 32 56');
	StartItem ();
};


void() health_touch =
{
	local	float amount;
	local	string	s;
	
	if (other.classname != "player")
		return;
	
	if (self.healtype == 2) // Megahealth?  Ignore max_health...
	{
		if (!T_Heal(other, self.healamount, 1))
			return;
	}
	else
	{
		if (!T_Heal(other, self.healamount, 0))
			return;
	}
	
	sprint(other, "You receive ");
	s = ftos(self.healamount);
	sprint(other, s);
	sprint(other, " health\n");
	
// health touch sound
	sound(other, CHAN_ITEM, self.noise, 1, ATTN_NORM);

	stuffcmd (other, "bf\n");
	
	self.model = string_null;
	self.solid = SOLID_NOT;

//MY MOD: NO MEGAHEALTH ROT

	if (deathmatch != 2)		// deathmatch 2 is the silly old rules
	{
		if (deathmatch)
			self.nextthink = time + 20;
		self.think = SUB_regen;
	}
	
	activator = other;
	SUB_UseTargets();				// fire all targets / killtargets
};	

void() item_megahealth_rot =
{
	other = self.owner;
	
	if (other.health > other.max_health)
	{
		other.health = other.health - 1;
		self.nextthink = time + 1;
		return;
	}

// it is possible for a player to die and respawn between rots, so don't
// just blindly subtract the flag off
	other.items = other.items - (other.items & IT_SUPERHEALTH);
	
	if (deathmatch == 1)	// deathmatch 2 is silly old rules
	{
		self.nextthink = time + 20;
		self.think = SUB_regen;
	}
};

/*
===============================================================================

ARMOR

===============================================================================
*/

void() armor_touch;

void() armor_touch =
{
	local	float	type, value, bit;
	
	if (other.health <= 0)
		return;
	if (other.classname != "player")
		return;

	if (self.classname == "item_armor1")
	{
		bit = IT_ARMOR1;
	}
	if (self.classname == "item_armor2")
	{
		bit = IT_ARMOR2;
	}
	if (self.classname == "item_armorInv")
	{
		bit = IT_ARMOR3;
	}

	other.armortype = self.armortype;
	other.armorvalue = self.armorvalue;
	other.items = other.items - (other.items & (IT_ARMOR1 | IT_ARMOR2 | IT_ARMOR3)) + bit;

	self.solid = SOLID_NOT;
	self.model = string_null;
	if (deathmatch == 1)
		self.nextthink = time + 20;
	self.think = SUB_regen;

	sprint(other, "You got ");
	sprint(other, self.netname);
	sprint(other, "-resistant armor\n");
// armor touch sound
	sound(other, CHAN_ITEM, "items/armor1.wav", 1, ATTN_NORM);
	stuffcmd (other, "bf\n");
	
	activator = other;
	SUB_UseTargets();				// fire all targets / killtargets
};


/*QUAKED item_armor1 (0 .5 .8) (-16 -16 0) (16 16 32)
*/

void() item_armor1 =
{
	self.touch = armor_touch;
	precache_model ("progs/armor.mdl");
	setmodel (self, "progs/armor.mdl");
	self.skin = 0;
	setsize (self, '-16 -16 0', '16 16 56');

	self.netname = "Nails";
	self.armortype = AT_NAILS;
	self.armorvalue = 200;

	StartItem ();
};

/*QUAKED item_armor2 (0 .5 .8) (-16 -16 0) (16 16 32)
*/

void() item_armor2 =
{
	self.touch = armor_touch;
	precache_model ("progs/armor.mdl");
	setmodel (self, "progs/armor.mdl");
	self.skin = 1;
	setsize (self, '-16 -16 0', '16 16 56');

	self.netname = "Explosion";
	self.armortype = AT_EXPLOSION;
	self.armorvalue = 150;

	StartItem ();
};

/*QUAKED item_armorInv (0 .5 .8) (-16 -16 0) (16 16 32)
*/

void() item_armorInv =
{
	self.touch = armor_touch;
	precache_model ("progs/armor.mdl");
	setmodel (self, "progs/armor.mdl");
	self.skin = 2;
	setsize (self, '-16 -16 0', '16 16 56');

	self.netname = "Bullets";
	self.armortype = AT_BULLETS;
	self.armorvalue = 100;

	StartItem ();
};

/*
===============================================================================

WEAPONS

===============================================================================
*/

void() bound_other_ammo =
{
	if (other.ammo_shells > 100)
		other.ammo_shells = 100;
	if (other.ammo_nails > 200)
		other.ammo_nails = 200;
	if (other.ammo_rockets > 100)
		other.ammo_rockets = 100;		
	if (other.ammo_cells > 100)
		other.ammo_cells = 100;		
};


/*
=============
weapon_touch
=============
*/

void() weapon_pickup =
{
	local	float	hadammo, best, new, old;
	local	entity	stemp;
	local	float	leave;

	local entity e;


// if the player was using his best weapon, change up to the new one if better		
	stemp = self;
	self = other;
	self = stemp;

	sprint (other, "You got the ");
	sprint (other, self.player_weapon_name);
	sprint (other, "\n");
// weapon touch sound
	sound (other, CHAN_ITEM, "weapons/pkup.wav", 1, ATTN_NORM);
	stuffcmd (other, "bf\n");

// change to the weapon

	e = spawn();

	e.player_attack_frame = other.player_attack_frame;
	e.player_attack_func = other.player_attack_func;
//	e.player_attack_delay = other.player_attack_delay;
	e.player_weapon_model = other.player_weapon_model;
	e.player_weapon_name = other.player_weapon_name;
	e.player_item_model = other.player_item_model;
//	e.player_burst_count = other.player_burst_count;
//	e.player_burst_delay = other.player_burst_delay;
//	e.angles = other.angles;

	other.player_attack_frame = self.player_attack_frame;
	other.player_attack_func = self.player_attack_func;
//	other.player_attack_delay = self.player_attack_delay;
	other.player_weapon_model = self.player_weapon_model;
	other.player_weapon_name = self.player_weapon_name;
	other.player_item_model = self.player_item_model;
//	other.player_burst_count = self.player_burst_count;
//	other.player_burst_delay = self.player_burst_delay;
//	other.angles = self.angles;

	self.player_attack_frame = e.player_attack_frame;
	self.player_attack_func = e.player_attack_func;
//	self.player_attack_delay = e.player_attack_delay;
	self.player_weapon_model = e.player_weapon_model;
	self.player_weapon_name = e.player_weapon_name;
	self.player_item_model = e.player_item_model;
//	self.player_burst_count = e.player_burst_count;
//	self.player_burst_delay = e.player_burst_delay;
//	self.angles = e.angles;

	if (!coop && !deathmatch) {
		e.currentammo = other.currentammo;
		other.currentammo = self.currentammo;
		self.currentammo = e.currentammo;
	}

	remove(e);

	stemp = self;
	self = other;

	W_SetCurrentAmmo();

	self = stemp;


	setmodel(self, self.player_item_model);
	setsize(self, self.dest1, self.dest2);

	SUB_UseTargets();				// fire all targets / killtargets
};

void() weapon_touch =
{
	if (!(other.flags & FL_CLIENT))
		return;

	centerprint(other, self.player_weapon_name);

	if (other.get_button)
	{
		weapon_pickup();
		other.get_button = 0;
	}
};


float   BIG_GUN_MAX     = 25;

void() W_FireGoreShaft;			//bullets / unelemental
void() W_FireMadDogTannon;		//bullets
void() W_FireChaingun;			//bullets
void() W_FireBigassShotgun;		//bullets
void() W_FirePindicator;		//bullets
void() W_FireFatGun;			//bullets
void() W_FireAutoGrenade;		//explosion
void() W_FireClusterGrenade;	//explosion
void() W_FireBlinkGun;			//explosion
void() W_FireScreamCannon;		//explosion
void() W_FireBigGun;			//explosion
void() W_FireVaccuumMortar;		//explosion
void() W_FireScrambledEggs;		//explosion
void() W_FireMadGun;			//lightning
void() W_FireMegaBomb;			//lightning
void() W_FireSquidgyBomb;		//poison
void() W_FirePoisonGun;			//poison
void() W_FireBurlyNailgun;		//nails
void() W_FireRainGun;			//nails
void() W_FireDeathAxe;			//unelemental
void() W_FireTKAxe;             //unelemental
void() W_FireHunterSeeker;		//unelemental
void() W_FireSOS;               //unelemental
void() W_FireDisaster;          //nails
void() W_FireLazer;				//lightning
//void() W_FireHolyStriker;               //explosion
//void() W_FireSneakyShot;                //nails

void(float big_gun) SetMyWeapon = {
	if (big_gun <= 1) {

		self.player_weapon_name = "Homing Burly Nailgun";
		self.player_item_model = "progs/g_nail.mdl";
		self.player_attack_frame = player_shot1;
		self.player_attack_func = W_FireBurlyNailgun;
//		self.player_attack_delay = 0.1;
		self.player_weapon_model = "progs/v_nail.mdl";

//		self.player_burst_count = 10;
//		self.player_burst_delay = 0.6;

	} else if (big_gun <= 2) {

		self.player_weapon_name = "Blink Cannon";
		self.player_item_model = "progs/g_rock2.mdl";
		self.player_attack_frame = player_rocket1;
		self.player_attack_func = W_FireBlinkGun;
//		self.player_attack_delay = 0.8;
		self.player_weapon_model = "progs/v_rock2.mdl";

//		self.player_burst_count = 5;
//		self.player_burst_delay = 1.8;

	} else if (big_gun <= 3) {

		self.player_weapon_name = "Scream Cannon";
		self.player_item_model = "progs/g_rock.mdl";
		self.player_attack_frame = player_rocket1;
		self.player_attack_func = W_FireScreamCannon;
//		self.player_attack_delay = 0.6;
		self.player_weapon_model = "progs/v_rock.mdl";

//		self.player_burst_count = 3;
//		self.player_burst_delay = 2.6;

	} else if (big_gun <= 4) {

		self.player_weapon_name = "BigASS Shotgun";
		self.player_item_model = "progs/g_shot.mdl";
		self.player_attack_frame = player_shot1;
		self.player_attack_func = W_FireBigassShotgun;
//		self.player_attack_delay = 1.0;
		self.player_weapon_model = "progs/v_shot2.mdl";

//		self.player_burst_count = 2;
//		self.player_burst_delay = 1.5;

	} else if (big_gun <= 5) {

		self.player_weapon_name = "Poison Dart Gun";
		self.player_item_model = "progs/g_shot.mdl";
		self.player_attack_frame = player_shot1;
		self.player_attack_func = W_FirePoisonGun;
//		self.player_attack_delay = 0.2;
		self.player_weapon_model = "progs/v_shot.mdl";

//		self.player_burst_count = 10;
//		self.player_burst_delay = 1.2;

	} else if (big_gun <= 6) {

		self.player_weapon_name = "BIG GUN";
		self.player_item_model = "progs/g_nail2.mdl";
		self.player_attack_frame = player_rocket1;
		self.player_attack_func = W_FireBigGun;
//		self.player_attack_delay = 0.1;
		self.player_weapon_model = "progs/v_nail2.mdl";

//		self.player_burst_count = 3;
//		self.player_burst_delay = 0.6;

	} else if (big_gun <= 7) {

		self.player_weapon_name = "Hunter Seeker";
		self.player_item_model = "progs/g_light.mdl";
		self.player_attack_frame = player_rocket1;
		self.player_attack_func = W_FireHunterSeeker;
//		self.player_attack_delay = 0.8;
		self.player_weapon_model = "progs/v_light.mdl";

//		self.player_burst_count = 10;
//		self.player_burst_delay = 3.5;

	} else if (big_gun <= 8) {

		self.player_weapon_name = "death axe";
		self.player_item_model = "progs/v_axe.mdl";
		self.player_attack_frame = player_axe_start;
		self.player_attack_func = W_FireDeathAxe;
//		self.player_attack_delay = 0.3;
		self.player_weapon_model = "progs/v_axe.mdl";

//		self.player_burst_count = 2;
//		self.player_burst_delay = 0.1;

	} else if (big_gun <= 9) {

		self.player_weapon_name = "telekinesis axe";
		self.player_item_model = "progs/v_axe.mdl";
		self.player_attack_frame = player_axe_start;
		self.player_attack_func = W_FireTKAxe;
//		self.player_attack_delay = 0.6;
		self.player_weapon_model = "progs/v_axe.mdl";

//		self.player_burst_count = 3;
//		self.player_burst_delay = 1.8;

	} else if (big_gun <= 10) {

		self.player_weapon_name = "Gore Shaft";
		self.player_item_model = "progs/g_shot.mdl";
		self.player_attack_frame = player_shot1;
		self.player_attack_func = W_FireGoreShaft;
//		self.player_attack_delay = 0.6;
		self.player_weapon_model = "progs/v_shot.mdl";

//		self.player_burst_count = 5;
//		self.player_burst_delay = 1.2;

	} else if (big_gun <= 11) {

		self.player_weapon_name = "Rain Gun";
		self.player_item_model = "progs/g_shot.mdl";
		self.player_attack_frame = player_shot1;
		self.player_attack_func = W_FireRainGun;
//		self.player_attack_delay = 0.4;
		self.player_weapon_model = "progs/v_shot.mdl";

//		self.player_burst_count = 2;
//		self.player_burst_delay = 0.7;

	} else if (big_gun <= 12) {

		self.player_weapon_name = "Auto Grenade Launcher";
		self.player_item_model = "progs/g_rock.mdl";
		self.player_attack_frame = player_rocket1;
		self.player_attack_func = W_FireAutoGrenade;
//		self.player_attack_delay = 0.1;
		self.player_weapon_model = "progs/v_rock.mdl";

//		self.player_burst_count = 10;
//		self.player_burst_delay = 0.6;

	} else if (big_gun <= 13) {

		self.player_weapon_name = "Chaingun";
		self.player_item_model = "progs/g_nail2.mdl";
		self.player_attack_frame = player_nail1;
		self.player_attack_func = W_FireChaingun;
//		self.player_attack_delay = 0.1;
		self.player_weapon_model = "progs/v_nail2.mdl";

//		self.player_burst_count = 5;
//		self.player_burst_delay = 0.3;

	} else if (big_gun <= 14) {

		self.player_weapon_name = "Cluster Grenades";
		self.player_item_model = "progs/g_rock.mdl";
		self.player_attack_frame = player_rocket1;
		self.player_attack_func = W_FireClusterGrenade;
//		self.player_attack_delay = 1.0;
		self.player_weapon_model = "progs/v_rock.mdl";

//		self.player_burst_count = 3;
//		self.player_burst_delay = 1.7;

	} else if (big_gun <= 15) {

		self.player_weapon_name = "Mad Gun";
		self.player_attack_frame = player_rocket1;
		self.player_attack_func = W_FireMadGun;
//		self.player_attack_delay = 1.1;
		self.player_weapon_model = "progs/v_light.mdl";
		self.player_item_model = "progs/g_light.mdl";

//		self.player_burst_count = 5;
//		self.player_burst_delay = 2.4;

	} else if (big_gun <= 16) {

		self.player_weapon_name = "Squidgy Bomb";
		self.player_attack_frame = player_rocket1;
		self.player_attack_func = W_FireSquidgyBomb;
//		self.player_attack_delay = 0.6;
		self.player_weapon_model = "progs/v_rock.mdl";
		self.player_item_model = "progs/g_rock.mdl";

//		self.player_burst_count = 5;
//		self.player_burst_delay = 2.3;

	} else if (big_gun <= 17) {

		self.player_weapon_name = "Mad Dog Tannon Gun";
		self.player_item_model = "progs/g_shot.mdl";
		self.player_attack_frame = player_shot1;
		self.player_attack_func = W_FireMadDogTannon;
//		self.player_attack_delay = 10;
		self.player_weapon_model = "progs/v_shot2.mdl";

//		self.player_burst_count = 10;
//		self.player_burst_delay = 30;

	} else if (big_gun <= 18) {

		self.player_weapon_name = "Pindicator";
		self.player_item_model = "progs/g_nail2.mdl";
		self.player_attack_frame = player_nail1;
		self.player_attack_func = W_FirePindicator;
//		self.player_attack_delay = 0.1;
		self.player_weapon_model = "progs/v_nail2.mdl";

//		self.player_burst_count = 5;
//		self.player_burst_delay = 0.3;

	} else if (big_gun <= 19) {

		self.player_weapon_name = "Mega Head Bomb";
		self.player_item_model = "progs/g_rock.mdl";
		self.player_attack_frame = player_rocket1;
		self.player_attack_func = W_FireMegaBomb;
//		self.player_attack_delay = 1;
		self.player_weapon_model = "progs/v_rock.mdl";

//		self.player_burst_count = 2;
//		self.player_burst_delay = 0.8;

	} else if (big_gun <= 20) {

		self.player_weapon_name = "Fat Gun";
		self.player_item_model = "progs/g_shot.mdl";
		self.player_attack_frame = player_shot1;
		self.player_attack_func = W_FireFatGun;
//		self.player_attack_delay = 0.6;
		self.player_weapon_model = "progs/v_shot.mdl";

//		self.player_burst_count = 15;
//		self.player_burst_delay = 1.8;

	} else if (big_gun <= 21) {

		self.player_weapon_name = "VaccuumMortar";
		self.player_item_model = "progs/g_rock2.mdl";
		self.player_attack_frame = player_rocket1;
		self.player_attack_func = W_FireVaccuumMortar;
//		self.player_attack_delay = 2;
		self.player_weapon_model = "progs/v_rock2.mdl";

//		self.player_burst_count = 3;
//		self.player_burst_delay = 3;

	} else if (big_gun <= 22) {

		self.player_weapon_name = "Scrambled Eggs";
		self.player_item_model = "progs/g_rock2.mdl";
		self.player_attack_frame = player_rocket1;
		self.player_attack_func = W_FireScrambledEggs;
//		self.player_attack_delay = 1;
		self.player_weapon_model = "progs/v_rock2.mdl";

//		self.player_burst_count = 3;
//		self.player_burst_delay = 2;

	} else if (big_gun <= 23) {

		self.player_weapon_name = "SOS Gun";
		self.player_item_model = "progs/g_rock.mdl";
		self.player_attack_frame = player_rocket1;
		self.player_attack_func = W_FireSOS;
//		self.player_attack_delay = 1;
		self.player_weapon_model = "progs/v_rock.mdl";

//		self.player_burst_count = 1;
//		self.player_burst_delay = 0.1;

	} else if (big_gun <= 24) {

		self.player_weapon_name = "Disaster";
		self.player_item_model = "progs/g_nail.mdl";
		self.player_attack_frame = player_shot1;
		self.player_attack_func = W_FireDisaster;
//		self.player_attack_delay = 0.2;
		self.player_weapon_model = "progs/v_nail.mdl";

//		self.player_burst_count = 1;
//		self.player_burst_delay = 0.1;

	} else if (big_gun <= 25) {

		self.player_weapon_name = "Lazer";
		self.player_item_model = "progs/g_nail2.mdl";
		self.player_attack_frame = player_shot1;
		self.player_attack_func = W_FireLazer;
//		self.player_attack_delay = 0.2;
		self.player_weapon_model = "progs/v_nail2.mdl";

//		self.player_burst_count = 2;
//		self.player_burst_delay = 0.1;
//      } else if (big_gun <= 26) {
//
//              self.player_weapon_name = "Holy Striker";
//              self.player_item_model = "progs/g_rock.mdl";
//              self.player_attack_frame = player_rocket1;
//              self.player_attack_func = W_FireHolyStriker;
//              self.player_attack_delay = 1.0;
//              self.player_weapon_model = "progs/v_rock.mdl";
//
//		self.player_burst_count = 10;
//		self.player_burst_delay = 0.6;
//
//      } else if (big_gun <= 27) {
//
//              self.player_weapon_name = "Secret Shot";
//              self.player_item_model = "progs/g_nail.mdl";
//              self.player_attack_frame = player_shot1;
//              self.player_attack_func = W_FireSecretShot;
//              self.player_attack_delay = 0.1;
//              self.player_weapon_model = "progs/v_nail.mdl";

//		self.player_burst_count = 10;
//		self.player_burst_delay = 0.6;
        }

	self.currentammo = 50;
};

void() MyWeaponChange =
{
	self.nextthink = time + 150 * (1.0 + random());

	SetMyWeapon(random() * BIG_GUN_MAX);

	self.angles = '0 0 0';
	if (self.player_item_model == "progs/v_axe.mdl")
		self.angles = '180 0 0';

	setmodel(self, self.player_item_model);
	setsize(self, self.dest1, self.dest2);
};

void() MyPlaceItem =
{
	PlaceItem();

	if (self == world) return;

	if (deathmatch)
	{
		self.nextthink = time + 150 * (1.0 + random());
		self.think = MyWeaponChange;
	}
};

entity() DropRune;

void() StartMyWeapons =
{

	SetMyWeapon(random() * BIG_GUN_MAX);

	self.angles = '0 0 0';
	if (self.player_item_model == "progs/v_axe.mdl")
		self.angles = '180 0 0';

	setmodel(self, self.player_item_model);
	setsize(self, self.dest1, self.dest2);

	self.touch = weapon_touch;

	self.nextthink = time + 0.2;
	self.think = MyPlaceItem;
};

/*QUAKED weapon_supershotgun (0 .5 .8) (-16 -16 0) (16 16 32)
*/

void() weapon_supershotgun =
{
	self.dest1 = '-16 -16 0';
	self.dest2 = '16 16 56';
	StartMyWeapons ();
};

/*QUAKED weapon_nailgun (0 .5 .8) (-16 -16 0) (16 16 32)
*/

void() weapon_nailgun =
{
	self.dest1 = '-16 -16 0';
	self.dest2 = '16 16 56';
	StartMyWeapons ();
};

/*QUAKED weapon_supernailgun (0 .5 .8) (-16 -16 0) (16 16 32)
*/

void() weapon_supernailgun =
{
	self.dest1 = '-16 -16 0';
	self.dest2 = '16 16 56';
	StartMyWeapons ();
};

/*QUAKED weapon_grenadelauncher (0 .5 .8) (-16 -16 0) (16 16 32)
*/

void() weapon_grenadelauncher =
{
	self.dest1 = '-16 -16 0';
	self.dest2 = '16 16 56';
	StartMyWeapons ();
};

/*QUAKED weapon_rocketlauncher (0 .5 .8) (-16 -16 0) (16 16 32)
*/

void() weapon_rocketlauncher =
{
	self.dest1 = '-16 -16 0';
	self.dest2 = '16 16 56';
	StartMyWeapons ();
};


/*QUAKED weapon_lightning (0 .5 .8) (-16 -16 0) (16 16 32)
*/

void() weapon_lightning =
{
	self.dest1 = '-16 -16 0';
	self.dest2 = '16 16 56';
	StartMyWeapons ();
};


/*
===============================================================================

AMMO

===============================================================================
*/

//************************* UNUSED ************************* 

void() ammo_touch =
{
local entity	stemp;
local float		best;

	if (other.classname != "player")
		return;
	if (other.health <= 0)
		return;

// if the player was using his best weapon, change up to the new one if better		
	stemp = self;
	self = other;
	self = stemp;


// shotgun
	if (self.weapon == 1)
	{
		if (other.ammo_shells >= 100)
			return;
		other.ammo_shells = other.ammo_shells + self.aflag;
	}

// spikes
	if (self.weapon == 2)
	{
		if (other.ammo_nails >= 200)
			return;
		other.ammo_nails = other.ammo_nails + self.aflag;
	}

//	rockets
	if (self.weapon == 3)
	{
		if (other.ammo_rockets >= 100)
			return;
		other.ammo_rockets = other.ammo_rockets + self.aflag;
	}

//	cells
	if (self.weapon == 4)
	{
		if (other.ammo_cells >= 100)
			return;
		other.ammo_cells = other.ammo_cells + self.aflag;
	}

	bound_other_ammo ();
	
	sprint (other, "You got the ");
	sprint (other, self.netname);
	sprint (other, "\n");
// ammo touch sound
	sound (other, CHAN_ITEM, "weapons/lock4.wav", 1, ATTN_NORM);
	stuffcmd (other, "bf\n");

// change to a better weapon if appropriate

// if changed current ammo, update it
	stemp = self;
	self = other;
	W_SetCurrentAmmo();
	self = stemp;

// remove it in single player, or setup for respawning in deathmatch
	self.model = string_null;
	self.solid = SOLID_NOT;
	if (deathmatch == 1)
		self.nextthink = time + 30;
	self.think = SUB_regen;

	activator = other;
	SUB_UseTargets();				// fire all targets / killtargets
};




float WEAPON_BIG2 = 1;

/*QUAKED item_shells (0 .5 .8) (0 0 0) (32 32 32) big
*/

void() item_shells =
{
	self.dest1 = '0 0 0';
	self.dest2 = '32 32 56';

	StartMyWeapons ();
/*
	self.touch = ammo_touch;

	if (self.spawnflags & WEAPON_BIG2)
	{
		precache_model ("maps/b_shell1.bsp");
		setmodel (self, "maps/b_shell1.bsp");
		self.aflag = 40;
	}
	else
	{
		precache_model ("maps/b_shell0.bsp");
		setmodel (self, "maps/b_shell0.bsp");
		self.aflag = 20;
	}
	self.weapon = 1;
	self.netname = "shells";
	setsize (self, '0 0 0', '32 32 56');
	StartItem ();
*/
};

/*QUAKED item_spikes (0 .5 .8) (0 0 0) (32 32 32) big
*/

void() item_spikes =
{
	self.dest1 = '0 0 0';
	self.dest2 = '32 32 56';

	StartMyWeapons ();
/*
	self.touch = ammo_touch;

	if (self.spawnflags & WEAPON_BIG2)
	{
		precache_model ("maps/b_nail1.bsp");
		setmodel (self, "maps/b_nail1.bsp");
		self.aflag = 50;
	}
	else
	{
		precache_model ("maps/b_nail0.bsp");
		setmodel (self, "maps/b_nail0.bsp");
		self.aflag = 25;
	}
	self.weapon = 2;
	self.netname = "nails";
	setsize (self, '0 0 0', '32 32 56');
	StartItem ();
*/
};

/*QUAKED item_rockets (0 .5 .8) (0 0 0) (32 32 32) big
*/

void() item_rockets =
{
	self.dest1 = '0 0 0';
	self.dest2 = '32 32 56';
	StartMyWeapons ();

/*
	self.touch = ammo_touch;

	if (self.spawnflags & WEAPON_BIG2)
	{
		precache_model ("maps/b_rock1.bsp");
		setmodel (self, "maps/b_rock1.bsp");
		self.aflag = 10;
	}
	else
	{
		precache_model ("maps/b_rock0.bsp");
		setmodel (self, "maps/b_rock0.bsp");
		self.aflag = 5;
	}
	self.weapon = 3;
	self.netname = "rockets";
	setsize (self, '0 0 0', '32 32 56');
	StartItem ();
*/
};


/*QUAKED item_cells (0 .5 .8) (0 0 0) (32 32 32) big
*/

void() item_cells =
{
	self.dest1 = '0 0 0';
	self.dest2 = '32 32 56';
	StartMyWeapons ();
/*
	self.touch = ammo_touch;

	if (self.spawnflags & WEAPON_BIG2)
	{
		precache_model ("maps/b_batt1.bsp");
		setmodel (self, "maps/b_batt1.bsp");
		self.aflag = 12;
	}
	else
	{
		precache_model ("maps/b_batt0.bsp");
		setmodel (self, "maps/b_batt0.bsp");
		self.aflag = 6;
	}
	self.weapon = 4;
	self.netname = "cells";
	setsize (self, '0 0 0', '32 32 56');
	StartItem ();
*/
};


/*QUAKED item_weapon (0 .5 .8) (0 0 0) (32 32 32) shotgun rocket spikes big
DO NOT USE THIS!!!! IT WILL BE REMOVED!
*/

float WEAPON_SHOTGUN = 1;
float WEAPON_ROCKET = 2;
float WEAPON_SPIKES = 4;
float WEAPON_BIG = 8;
void() item_weapon =
{
	self.dest1 = '0 0 0';
	self.dest2 = '32 32 56';
	StartMyWeapons ();

	return;
/*


	self.touch = ammo_touch;

	if (self.spawnflags & WEAPON_SHOTGUN)
	{
		if (self.spawnflags & WEAPON_BIG)
		{
			precache_model ("maps/b_shell1.bsp");
			setmodel (self, "maps/b_shell1.bsp");
			self.aflag = 40;
		}
		else
		{
			precache_model ("maps/b_shell0.bsp");
			setmodel (self, "maps/b_shell0.bsp");
			self.aflag = 20;
		}
		self.weapon = 1;
		self.netname = "shells";
	}

	if (self.spawnflags & WEAPON_SPIKES)
	{
		if (self.spawnflags & WEAPON_BIG)
		{
			precache_model ("maps/b_nail1.bsp");
			setmodel (self, "maps/b_nail1.bsp");
			self.aflag = 40;
		}
		else
		{
			precache_model ("maps/b_nail0.bsp");
			setmodel (self, "maps/b_nail0.bsp");
			self.aflag = 20;
		}
		self.weapon = 2;
		self.netname = "spikes";
	}

	if (self.spawnflags & WEAPON_ROCKET)
	{
		if (self.spawnflags & WEAPON_BIG)
		{
			precache_model ("maps/b_rock1.bsp");
			setmodel (self, "maps/b_rock1.bsp");
			self.aflag = 10;
		}
		else
		{
			precache_model ("maps/b_rock0.bsp");
			setmodel (self, "maps/b_rock0.bsp");
			self.aflag = 5;
		}
		self.weapon = 3;
		self.netname = "rockets";
	}
	
	setsize (self, '0 0 0', '32 32 56');
	StartItem ();
*/
};


/*
===============================================================================

KEYS

===============================================================================
*/

void() key_touch =
{
local entity	stemp;
local float		best;

	if (other.classname != "player")
		return;
	if (other.health <= 0)
		return;
	if (other.items & self.items)
		return;

	sprint (other, "You got the ");
	sprint (other, self.netname);
	sprint (other,"\n");

	sound (other, CHAN_ITEM, self.noise, 1, ATTN_NORM);
	stuffcmd (other, "bf\n");
	other.items = other.items | self.items;

	if (!coop)
	{	
		self.solid = SOLID_NOT;
		self.model = string_null;
	}

	activator = other;
	SUB_UseTargets();				// fire all targets / killtargets
};


void() key_setsounds =
{
	if (world.worldtype == 0)
	{
//		precache_sound ("misc/medkey.wav");
		self.noise = "misc/medkey.wav";
	}
	if (world.worldtype == 1)
	{
		precache_sound ("misc/runekey.wav");
		self.noise = "misc/runekey.wav";
	}
	if (world.worldtype == 2)
	{
		precache_sound2 ("misc/basekey.wav");
		self.noise = "misc/basekey.wav";
	}
};

/*QUAKED item_key1 (0 .5 .8) (-16 -16 -24) (16 16 32)
SILVER key
In order for keys to work
you MUST set your maps
worldtype to one of the
following:
0: medieval
1: metal
2: base
*/

void() item_key1 =
{
	if (world.worldtype == 0)
	{
		precache_model ("progs/w_s_key.mdl");
		setmodel (self, "progs/w_s_key.mdl");
		self.netname = "silver key";
	}
	else if (world.worldtype == 1)
	{
		precache_model ("progs/m_s_key.mdl");
		setmodel (self, "progs/m_s_key.mdl");
		self.netname = "silver runekey";
	}
	else if (world.worldtype == 2)
	{
		precache_model2 ("progs/b_s_key.mdl");
		setmodel (self, "progs/b_s_key.mdl");
		self.netname = "silver keycard";
	}
	key_setsounds();
	self.touch = key_touch;
	self.items = IT_KEY1;
	setsize (self, '-16 -16 -24', '16 16 32');
	StartItem ();
};

/*QUAKED item_key2 (0 .5 .8) (-16 -16 -24) (16 16 32)
GOLD key
In order for keys to work
you MUST set your maps
worldtype to one of the
following:
0: medieval
1: metal
2: base
*/

void() item_key2 =
{
	if (world.worldtype == 0)
	{
		precache_model ("progs/w_g_key.mdl");
		setmodel (self, "progs/w_g_key.mdl");
		self.netname = "gold key";
	}
	if (world.worldtype == 1)
	{
		precache_model ("progs/m_g_key.mdl");
		setmodel (self, "progs/m_g_key.mdl");
		self.netname = "gold runekey";
	}
	if (world.worldtype == 2)
	{
		precache_model2 ("progs/b_g_key.mdl");
		setmodel (self, "progs/b_g_key.mdl");
		self.netname = "gold keycard";
	}
	key_setsounds();
	self.touch = key_touch;
	self.items = IT_KEY2;
	setsize (self, '-16 -16 -24', '16 16 32');
	StartItem ();
};



/*
===============================================================================

END OF LEVEL RUNES

===============================================================================
*/

void() sigil_touch =
{
local entity	stemp;
local float		best;

	if (other.classname != "player")
		return;
	if (other.health <= 0)
		return;

	centerprint (other, "You got the rune!");

	sound (other, CHAN_ITEM, self.noise, 1, ATTN_NORM);
	stuffcmd (other, "bf\n");
	self.solid = SOLID_NOT;
	self.model = string_null;
	serverflags = serverflags | (self.spawnflags & 15);
	self.classname = "";		// so rune doors won't find it
	
	activator = other;
	SUB_UseTargets();				// fire all targets / killtargets
};


/*QUAKED item_sigil (0 .5 .8) (-16 -16 -24) (16 16 32) E1 E2 E3 E4
End of level sigil, pick up to end episode and return to jrstart.
*/

void() item_sigil =
{
//	if (deathmatch) {
//		DropRune();
//		return;
//	}

	if (!self.spawnflags)
		objerror ("no spawnflags");

	precache_sound ("misc/runekey.wav");
	self.noise = "misc/runekey.wav";

	if (self.spawnflags & 1) {
		precache_model ("progs/end1.mdl");
		setmodel (self, "progs/end1.mdl");
	}

	if (self.spawnflags & 2) {
		precache_model2 ("progs/end2.mdl");
		setmodel (self, "progs/end2.mdl");
	}

	if (self.spawnflags & 4) {
		precache_model2 ("progs/end3.mdl");
		setmodel (self, "progs/end3.mdl");
	}

	if (self.spawnflags & 8) {
		precache_model2 ("progs/end4.mdl");
		setmodel (self, "progs/end4.mdl");
	}
	
	self.touch = sigil_touch;
	setsize (self, '-16 -16 -24', '16 16 32');
	StartItem ();
};

/*
===============================================================================

POWERUPS

===============================================================================
*/

void() powerup_touch;

void() powerup_touch = {

	local entity	stemp;
	local float		best;

	if (other.classname != "player")
		return;
	if (other.health <= 0)
		return;

	sprint (other, "You got the ");
	sprint (other, self.netname);
	sprint (other,"\n");

	if (deathmatch) {

		self.mdl = self.model;
		
		if ((self.classname == "item_artifact_invulnerability") ||
			(self.classname == "item_artifact_invisibility"))
			self.nextthink = time + 60*5;
		else
			self.nextthink = time + 60;
		
		self.think = SUB_regen;
	}	

	sound (other, CHAN_VOICE, self.noise, 1, ATTN_NORM);
	stuffcmd (other, "bf\n");
	self.solid = SOLID_NOT;
	other.items = other.items | self.items;
	self.model = string_null;

// do the apropriate action
	if (self.classname == "item_artifact_envirosuit") {
		other.rad_time = 1;
		other.radsuit_finished = time + 30;
	}
	
	if (self.classname == "item_artifact_invulnerability") {
		other.invincible_time = 1;
		other.invincible_finished = time + 30;
	}
	
	if (self.classname == "item_artifact_invisibility") {
		other.invisible_time = 1;
		other.invisible_finished = time + 30;
	}

	if (self.classname == "item_artifact_super_damage") {
		other.super_time = 1;
		other.super_damage_finished = time + 30;
	}	

	activator = other;
	SUB_UseTargets();				// fire all targets / killtargets
};



/*QUAKED item_artifact_invulnerability (0 .5 .8) (-16 -16 -24) (16 16 32)
Player is invulnerable for 30 seconds
*/
void() item_artifact_invulnerability = {

	self.touch = powerup_touch;

	precache_model ("progs/invulner.mdl");
	precache_sound ("items/protect.wav");
//	precache_sound ("items/protect2.wav");	//now in world.qc
//	precache_sound ("items/protect3.wav");
	self.noise = "items/protect.wav";
	setmodel (self, "progs/invulner.mdl");
	self.netname = "Pentagram of Protection";
	self.items = IT_INVULNERABILITY;
	setsize (self, '-16 -16 -24', '16 16 32');
	StartItem ();
};

/*QUAKED item_artifact_envirosuit (0 .5 .8) (-16 -16 -24) (16 16 32)
Player takes no damage from water or slime for 30 seconds
*/
void() item_artifact_envirosuit = {
	self.touch = powerup_touch;

	precache_model ("progs/suit.mdl");
	precache_sound ("items/suit.wav");
	precache_sound ("items/suit2.wav");
	self.noise = "items/suit.wav";
	setmodel (self, "progs/suit.mdl");
	self.netname = "Biosuit";
	self.items = IT_SUIT;
	setsize (self, '-16 -16 -24', '16 16 32');
	StartItem ();
};


/*QUAKED item_artifact_invisibility (0 .5 .8) (-16 -16 -24) (16 16 32)
Player is invisible for 30 seconds
*/
void() item_artifact_invisibility =
{
	self.touch = powerup_touch;

	precache_model ("progs/invisibl.mdl");
	precache_sound ("items/inv1.wav");
	precache_sound ("items/inv2.wav");
	precache_sound ("items/inv3.wav");
	self.noise = "items/inv1.wav";
	setmodel (self, "progs/invisibl.mdl");
	self.netname = "Ring of Shadows";
	self.items = IT_INVISIBILITY;
	setsize (self, '-16 -16 -24', '16 16 32');
	StartItem ();
};


/*QUAKED item_artifact_super_damage (0 .5 .8) (-16 -16 -24) (16 16 32)
The next attack from the player will do 4x damage
*/
void() item_artifact_super_damage =
{
	self.touch = powerup_touch;

	precache_model ("progs/quaddama.mdl");
	precache_sound ("items/damage.wav");
	precache_sound ("items/damage2.wav");
	precache_sound ("items/damage3.wav");
	self.noise = "items/damage.wav";
	setmodel (self, "progs/quaddama.mdl");
	self.netname = "Quad Damage";
	self.items = IT_QUAD;
	setsize (self, '-16 -16 -24', '16 16 32');
	StartItem ();
};


/*
===============================================================================

PLAYER BACKPACKS ********** PWNED N00B!!!! i jacked this and made it into runes

===============================================================================
*/

void() SmiteEveryone = {
	local	entity	e;
	while (e = nextent(e)) {
		if (e.flags & FL_CLIENT) {
			bring_on_the_smite(e);
		}
	}
};

void() rune_touch = {
	local string	s;
	local	float	best, old, new;
	local		entity	stemp;
	local	float	acount;

// only players can get the rune

	if (other.classname != "player")
		return;

// only let living players
	if (other.health <= 0)
		return;

	sprint (other, "You get the Rune of ");
	sprint (other, self.netname);
	sprint (other, "\n");


// backpack touch sound
	sound (other, CHAN_ITEM, "weapons/lock4.wav", 1, ATTN_NORM);
	stuffcmd (other, "bf\n");

	if (self.netname == "Your Mom") {
		SmiteEveryone();
	} else {
		other.rune_vampire_count = other.rune_vampire_count + self.rune_vampire_count;
		other.rune_autoaim_count = other.rune_autoaim_count + self.rune_autoaim_count;
		other.rune_thorns_count = other.rune_thorns_count + self.rune_thorns_count;
		other.rune_armor_count = other.rune_armor_count + self.rune_armor_count;
		other.rune_quad_count = other.rune_quad_count + self.rune_quad_count;
		other.rune_burst_count = other.rune_burst_count + self.rune_burst_count;
		other.rune_regen_count = other.rune_regen_count + self.rune_regen_count;
		other.rune_invis_count = other.rune_invis_count + self.rune_invis_count;
		other.rune_freeze_count = other.rune_freeze_count  + self.rune_freeze_count ;
		other.rune_revenge_count = other.rune_revenge_count + self.rune_revenge_count ;
	}

	remove(self);
};

/*
===============
DropBackpack
===============
*/

//make this drop a rune instead

void(float rnd) SpawnRuneInnards =
{
        self.classname = "item_rune";
        self.flags = FL_ITEM;
        self.solid = SOLID_TRIGGER;
        self.movetype = MOVETYPE_TOSS;

        self.netname = "No Rune";
        self.touch = rune_touch;             

        if (rnd <= 1) {
                setmodel(self, "progs/w_s_key.mdl");
                self.rune_quad_count = 1;
                self.netname = "Quad";
        } else if (rnd <= 2) {
                setmodel(self, "progs/m_s_key.mdl");
                self.rune_freeze_count = 1;
                self.netname = "Freeze Time";
        } else if (rnd <= 3) {
                setmodel(self, "progs/b_s_key.mdl");
                self.rune_vampire_count = 1;
                self.netname = "Vampire";
        } else if (rnd <= 4) {
                setmodel(self, "progs/w_g_key.mdl");
                self.rune_regen_count = 1;
                self.netname = "Regeneration";
        } else if (rnd <= 5) {
                setmodel(self, "progs/b_g_key.mdl");
                self.rune_burst_count = 1;
                self.netname = "Burst Fire";
        } else if (rnd <= 6) {
                setmodel(self, "progs/end2.mdl");
                self.rune_armor_count = 1;
                self.netname = "Resiliance";
        } else if (rnd <= 7) {
                setmodel(self, "progs/end3.mdl");
                self.rune_invis_count = 1;
                self.netname = "Cloaked Bird o' Prey";
        } else if (rnd <= 8) {
                setmodel(self, "progs/lavaball.mdl");
                self.rune_thorns_count = 1;
                self.netname = "Thorns";
        } else if (rnd <= 9) {
                setmodel(self, "progs/h_shams.mdl");
                self.rune_autoaim_count = 1;
                self.netname = "Autoaim";
        } else if (rnd <= 10) {
                setmodel(self, "progs/v_spike.mdl");
                self.rune_revenge_count = 1;
                self.netname = "Revenge";
        } else if (rnd <= 11) {
                setmodel(self, "progs/h_player.mdl");
                self.netname = "Your Mom";
        }

        setsize (self, '-16 -16 0', '16 16 56');

        self.effects = EF_BRIGHTFIELD;

        self.nextthink = time + 120;    // remove after 2 minutes
        self.think = SUB_Remove;
};

float RUNE_COUNT = 10;          

void() item_rune =
{
        local float     rnd;
        rnd = random() * 10;    //ingame-spawned runes
        SpawnRuneInnards(rnd);
};

entity(float runeType) DropRuneOfType = {

        local entity ret, stemp;

        stemp = self;

        self = spawn();
        self.origin = stemp.origin - '0 0 24';

        SpawnRuneInnards(runeType);     //do a rune spawn with the current self entity

        self.velocity_z = 400;
        self.velocity_x = -200 + (random() * 400);
        self.velocity_y = -200 + (random() * 400);

        ret = self;     //store this for reference to any proceeding code.
        self = stemp;

        return ret;
};

entity() DropRune = {

        local float     rnd;
        rnd = random() * 10;                  
        DropRuneOfType(rnd);          
};

//coz im too lazy to replace them all
void() DropBackpack = {
//                              Sean removing random chance hopefully.
//      if (random() > 0.15) return;
	DropRune();
};
