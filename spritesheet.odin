package gamejam

TEST_SAMURAI_IDLE :: Texture {
	path = "./temp_assets/samurai/Sprites/IDLE.png",
	divisions = 10,
	offset = {0, 100},
	scale = 3,
}
TEST_SAMURAI_ATTACK :: Texture {
	path = "./temp_assets/samurai/Sprites/ATTACK 1.png",
	divisions = 7,
	offset = {0, 100},
	scale = 3,
}
TEST_SAMURAI_WALK :: Texture {
	path = "./temp_assets/samurai/Sprites/RUN.png",
	divisions = 16,
	offset = {0, 100},
	scale = 3,
}

KNIGHT_IDLE :: Texture {
	path = "./KnightSpriteSheet/Knight_1/Idle.png",
	divisions = 4,
	offset = {0, 100},
	scale = 2.2,
}

KNIGHT_RUN :: Texture {
	path = "./KnightSpriteSheet/Knight_1/Run.png",
	divisions = 7,
	offset = {0, 100},
	scale = 2.2,
}

KNIGHT_DEFEND :: Texture {
	path = "./KnightSpriteSheet/Knight_1/Defend.png",
	divisions = 5,
	offset = {0, 100},
	scale = 2.2,
}

KNIGHT_ATTACK_BASIC :: Texture {
	path = "./KnightSpriteSheet/Knight_1/Attack 1.png",
	divisions = 5,
	offset = {0, 100},
	scale = 2.2,
}

KNIGHT_PRAY_RESPECTS :: Texture {
	path = "./KnightSpriteSheet/Knight_1/Kneel.png",
	divisions = 2,
	offset = {0, 100},
	scale = 2.2,
}

BIG_KNIGHT_IDLE :: Texture {
	path = "./HugeKnightSpriteSheet/Idle.png",
	divisions = 6,
	offset = {0, 50},
	scale = 2,
}

BIG_KNIGHT_ATTACK :: Texture {
	path = "./HugeKnightSpriteSheet/Attack.png",
	divisions = 8,
	offset = {0, 50},
	scale = 2,
}

BIG_KNIGHT_WALK :: Texture {
	path = "./HugeKnightSpriteSheet/Walk.png",
	divisions = 8,
	offset = {0, 30},
	scale = 2,
}

SAMURAI_IDLE :: Texture {
	path = "./SamuraiSpriteSheet/Samurai/Idle.png",
	divisions = 6,
	offset = {0, 100},
	scale = 2.2,
}

SAMURAI_ATTACK_BASIC :: Texture {
	path = "./SamuraiSpriteSheet/Samurai/Attack_1.png",
	divisions = 4,
	offset = {0, 100},
	scale = 2.2,
}

SAMURAI_RUN :: Texture {
	path = "./SamuraiSpriteSheet/Samurai/Run.png",
	divisions = 8,
	offset = {0, 100},
	scale = 2.2,
}

SAMURAI_DEAD :: Texture {
	path = "./SamuraiSpriteSheet/Samurai/Dead.png",
	divisions = 6,
	offset = {0, 100},
	scale = 2.2,
}

ARCHER_IDLE :: Texture {
	path = "./ArcherSpriteSheet/idle.png",
	divisions = 6,
	offset = {0, -20},
	scale = 1.5,
}
ARCHER_RUN :: Texture {
	path = "./ArcherSpriteSheet/walk.png",
	divisions = 8,
	offset = {0, -20},
	scale = 1.5,
}

ARCHER_ATTACK_BASIC :: Texture {
	path = "./ArcherSpriteSheet/attack.png",
	divisions = 8,
	offset = {0, -10},
	scale = 1.5,
}

GROUD_SLAM_PARTICLES :: Texture {
	path = "./GroundSlamSpritesheet.png",
	divisions = 10,
	scale = 1,
}

TIME_OF_ATTACK := #partial [Entity_Kind][Attack]int{
	.Test_Samurai = #partial {
		.Basic = 7,
		.Dash = 1,
	},
	.Knight = #partial {
		.Basic = 5,
		.Dash = 1,
		.Defend = 5,
		.Pray_Respects = 30,
	},
	.Archer = #partial {
		.Basic = 7,
		.Dash = 1,
	},
	.Samurai = #partial {
		.Basic = 4,
		.Dead = 6,
	},
	.Big_Knight = #partial {
		.Basic = 8,
		.Slam = 10,
	},
}
