//====================================================================
//
// GRAPPLING HOOK			by: Perecli Manole AKA Bort
//
//====================================================================
// Aside from this new file, the following are the modifications
// done to id's original source files:
//--------------------------------------------------------------------
// File: Progs.src
// Location: before the "weapons.qc" line
// Added: hook.qc
//--------------------------------------------------------------------
// File: Weapons.qc
// Procedure: ImpulseCommands
// Location: in the beginning of the function
// Added: CheckGrapHook ();
//--------------------------------------------------------------------
// File: World.qc
// Procedure: worldspawn
// Location: after line "precache_model ("progs/s_spike.mdl");"
// Added: precache_model ("progs/star.mdl");
//        precache_model ("progs/bit.mdl");
//--------------------------------------------------------------------
// File: Weapons.qc
// Procedure: W_Precache
// Location: end of procedure
// Added: precache_sound ("shambler/smack.wav");
//        precache_sound ("blob/land1.wav");
//--------------------------------------------------------------------
// File: Defs.qc
// Declaration group: player only fields
// Location: after line ".float pain_finished;"
// Added: .float hook;	
//--------------------------------------------------------------------


void(vector org, vector vel, float damage) SpawnBlood;	// prototype
float () crandom;   							// prototype


float	HOOK_OUT = 1;		// is hook currently extended? (bit flag)
float	HOOK_ON = 2;		// is ACTIVE_HOOK impulse on? (bit flag)
float ACTIVATE_HOOK = 69;       // impulse constant
float   TERMINATE_HOOK = 68;    // impulse constant


//--------------------------------------------------------------------
// Disolves chain
//--------------------------------------------------------------------
void (entity Head) DisolveChain =
{
	local entity link;

	link = Head.goalentity;
	while (link != world)
	{
		Head = link.goalentity;
		remove (link);
		link = Head;
	}
};


//--------------------------------------------------------------------
// Updated calculation of link positions
//--------------------------------------------------------------------
void () LinkPos =
{
	setorigin (self, self.owner.origin + ((self.enemy.origin + '0 0 16') - self.owner.origin) * self.weapon);
	self.nextthink = time + 0.01;
};


//--------------------------------------------------------------------
// Creates chain
//--------------------------------------------------------------------
entity (entity head, entity tail, float num) CreateChain =
{
	local entity link, prevlink;
	local float linknum;

	linknum = num;
	num = num + 1;
	prevlink = world;
	while (linknum > 0)
	{
		link = spawn();
		link.goalentity = prevlink;
		prevlink = link;
		link.owner = head;
		link.enemy = tail;
		link.weapon = linknum / num;
		link.movetype = MOVETYPE_NOCLIP;
		link.solid = SOLID_NOT;
		link.angles_z = 51 * linknum;
		link.angles_y = 41 * linknum;
		link.angles_x = 31 * linknum;
		link.avelocity = '310 410 510';
                setmodel (link, "progs/spike.mdl");
		setsize (link, '0 0 0', '0 0 0');
		setorigin (link, head.origin + ((tail.origin + '0 0 16') - head.origin) * link.weapon);
		link.nextthink = time + 0.01;
		link.think = LinkPos;
		linknum = linknum - 1;
	}
	return link;
};


//--------------------------------------------------------------------
// Removes star and detaches player
//--------------------------------------------------------------------
void () HookVanish =
{
	// removes flag of hook instance being present
	self.owner.hook = self.owner.hook - (self.owner.hook & HOOK_OUT);
        
	DisolveChain (self);
	remove (self);
};


//--------------------------------------------------------------------
// Hook pulls player function
//--------------------------------------------------------------------
void () HookPull =
{
        local vector vel, spray;
        local float v, ritem;
        local entity stemp;

	if ( 	((self.owner.hook & HOOK_ON) != HOOK_ON) || 
		(self.owner.teleport_time > time) || 
                (self.owner.deadflag) ||                        // if player dies
                (self.enemy.solid == SOLID_NOT) )               // if target dies
	{
		HookVanish();
		return;
	}
        if (self.enemy.takedamage)
        {
                T_Damage (self.enemy, self, self.owner, 1);
        }

        if (self.enemy.solid == SOLID_SLIDEBOX)
	{
		sound (self, CHAN_WEAPON, "blob/land1.wav", 1, ATTN_NORM);
		spray_x = 100 * crandom();
 		spray_y = 100 * crandom();
		spray_z = 100 * crandom() + 50;
		SpawnBlood (self.origin, spray, 20);
		setorigin (self, self.enemy.origin + self.enemy.mins + self.enemy.size * 0.5);
	}

        self.velocity = self.enemy.velocity;

/*

//hooked another player - equal pull on both
        if (self.enemy.flags & FL_CLIENT) {
                vel = self.owner.origin - self.enemy.origin;
                v = vlen (vel);
                if (v <= 100)
                        vel = normalize(vel) * v * 7;
                if ( v > 100 )
                        vel = normalize(vel) * 700;
                self.enemy.velocity = self.enemy.velocity + vel;

                vel = '0 0 0' - vel;
                self.owner.velocity = self.owner.velocity + vel;

                setorigin(self, self.enemy.origin);

        } else {

*/

//hooked else - pull you towards it

                vel = self.origin - (self.owner.origin + '0 0 16');
                v = vlen (vel);
                if (v <= 100)
                        vel = normalize(vel) * v * 15;
                if ( v > 100 )
                        vel = normalize(vel) * 1500;
                self.owner.velocity = vel;
//        }


	self.nextthink = time + 0.1;

};


//--------------------------------------------------------------------
// Star's touch function
//--------------------------------------------------------------------
void() T_ChainTouch =
{
	if ((self.owner.hook & HOOK_ON) != HOOK_ON)
	{
		HookVanish();
		return;
	}

//        if (other.takedamage) T_Damage (other, self, self.owner, 1);

 	if (other.solid == SOLID_SLIDEBOX)
	{
		sound (self, CHAN_WEAPON, "shambler/smack.wav", 1, ATTN_NORM);	
		SpawnBlood (self.origin, self.velocity, 10);
		setorigin (self, other.origin + other.mins + other.size * 0.5);
	}
	else
	{
		sound (self, CHAN_WEAPON, "player/axhit2.wav", 1, ATTN_NORM);
		self.avelocity = '0 0 0';
	}

	self.velocity = other.velocity;

	self.enemy = other;
	self.nextthink = time + 0.1;
	self.think = HookPull;
	self.touch = SUB_Null;
};


//--------------------------------------------------------------------
// Shoots star
//--------------------------------------------------------------------
void(entity myself) W_FireChain =
{
	local entity star;

	star = spawn ();
	star.owner = myself;
        star.classname = "grap_hook";
	star.movetype = MOVETYPE_FLY;
	star.solid = SOLID_BBOX;
        setmodel (star, "progs/s_spike.mdl");
        setsize (star, '0 0 0', '0 0 0');
	makevectors (myself.v_angle);
	setorigin (star, myself.origin + (v_forward*16) + '0 0 16' );
	star.velocity = v_forward*3000;
	star.angles = vectoangles(star.velocity);
	star.avelocity = '0 0 600';
        sound (myself, CHAN_WEAPON, "weapons/ax1.wav", 1, ATTN_NORM);

	star.touch = T_ChainTouch;
        star.nextthink = time + 5;     // reach length of grappling hook
	star.think = HookVanish;
	star.goalentity = CreateChain (star, myself, 8);
};


//--------------------------------------------------------------------
// Checks impulse
//--------------------------------------------------------------------
void() CheckGrapHook = 
{
	if (((self.hook & HOOK_OUT) != HOOK_OUT) && (self.impulse == ACTIVATE_HOOK))
	{
		// flags that one instance of hook is spawned
		self.hook = self.hook | HOOK_OUT;
	
		// flags last activated hook impulse as being ON 
		self.hook = self.hook | HOOK_ON;   

		W_FireChain (self);
		return;
	}

	if (((self.hook & HOOK_OUT) == HOOK_OUT) && (self.impulse == TERMINATE_HOOK))
	{
		// flags last activated hook impulse as being OFF
		self.hook = self.hook - (self.hook & HOOK_ON);
		
		return;
	}
}; 
