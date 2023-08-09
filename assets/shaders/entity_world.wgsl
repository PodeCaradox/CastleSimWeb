struct SingleInstance
{
	Index: u32,//image Index
	Animation: u32,// 8 bits for animation length // 12 bits for when update animation // 12 pausing frames TODO
    AtlasCoordPos: u32, //x/y for column/row z/w for image index
	AtlasCoordSize: u32,
};


struct EntityInstance
{
	Position: vec2<f32>,
	InstanceId: u32,
    AnimationIndex: u32
};