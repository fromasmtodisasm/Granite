#version 310 es

layout(set = 0, binding = 0, std140) uniform RenderParameters
{
    mat4 projection;
	mat4 view;
	mat4 view_projection;
	mat4 inv_projection;
	mat4 inv_view;
	mat4 inv_view_projection;
	mat4 inv_local_view_projection;

	vec3 camera_position;
	vec3 camera_front;
	vec3 camera_right;
	vec3 camera_up;
} global;

layout(location = 0) in highp vec3 Position;

#if HAVE_UV
layout(location = 1) in highp vec2 UV;
layout(location = 0) out highp vec2 vUV;
#endif

#if HAVE_NORMAL
layout(location = 2) in mediump vec3 Normal;
layout(location = 1) out mediump vec3 vNormal;
#endif

#if HAVE_TANGENT
layout(location = 3) in mediump vec3 Tangent;
layout(location = 2) out mediump vec3 vTangent;
#endif

#if HAVE_BONE_INDEX
layout(location = 4) in mediump uvec4 BoneIndices;
#endif

#if HAVE_BONE_WEIGHT
layout(location = 5) in mediump vec4 BoneWeights;
#endif

#if HAVE_BONE_INDEX && HAVE_BONE_WEIGHT
layout(std140, set = 3, binding = 1) uniform BonesWorld
{
    mat4 BoneWorldTransforms[256];
};

layout(std140, set = 3, binding = 2) uniform BonesNormal
{
    mat4 BoneNormalTransforms[256];
};
#else
struct StaticMeshInfo
{
    mat4 Model;
    mat4 Normal;
};

layout(set = 3, binding = 0, std140) uniform PerVertexData
{
    StaticMeshInfo infos[256];
};
#endif

void main()
{
#if HAVE_BONE_INDEX && HAVE_BONE_WEIGHT
    vec3 World =
        (
        BoneWorldTransforms[BoneIndices.x][0].xyz * BoneWeights.x +
        BoneWorldTransforms[BoneIndices.y][0].xyz * BoneWeights.y +
        BoneWorldTransforms[BoneIndices.z][0].xyz * BoneWeights.z +
        BoneWorldTransforms[BoneIndices.w][0].xyz * BoneWeights.w) * Position.x +

        (
        BoneWorldTransforms[BoneIndices.x][1].xyz * BoneWeights.x +
        BoneWorldTransforms[BoneIndices.y][1].xyz * BoneWeights.y +
        BoneWorldTransforms[BoneIndices.z][1].xyz * BoneWeights.z +
        BoneWorldTransforms[BoneIndices.w][1].xyz * BoneWeights.w) * Position.y +

        (
        BoneWorldTransforms[BoneIndices.x][2].xyz * BoneWeights.x +
        BoneWorldTransforms[BoneIndices.y][2].xyz * BoneWeights.y +
        BoneWorldTransforms[BoneIndices.z][2].xyz * BoneWeights.z +
        BoneWorldTransforms[BoneIndices.w][2].xyz * BoneWeights.w) * Position.z +

        (
        BoneWorldTransforms[BoneIndices.x][3].xyz * BoneWeights.x +
        BoneWorldTransforms[BoneIndices.y][3].xyz * BoneWeights.y +
        BoneWorldTransforms[BoneIndices.z][3].xyz * BoneWeights.z +
        BoneWorldTransforms[BoneIndices.w][3].xyz * BoneWeights.w);
#else
    vec3 World =
        infos[gl_InstanceIndex].Model[0].xyz * Position.x +
        infos[gl_InstanceIndex].Model[1].xyz * Position.y +
        infos[gl_InstanceIndex].Model[2].xyz * Position.z +
        infos[gl_InstanceIndex].Model[3].xyz;
#endif
    gl_Position = global.view_projection * vec4(World, 1.0);

#if HAVE_NORMAL
    #if HAVE_BONE_INDEX && HAVE_BONE_WEIGHT
        mat3 NormalTransform =
            mat3(BoneNormalTransforms[BoneIndices.x]) * BoneWeights.x +
            mat3(BoneNormalTransforms[BoneIndices.y]) * BoneWeights.y +
            mat3(BoneNormalTransforms[BoneIndices.z]) * BoneWeights.z +
            mat3(BoneNormalTransforms[BoneIndices.w]) * BoneWeights.w;
        vNormal = normalize(NormalTransform * Normal);
        #if HAVE_TANGENT
            vTangent = normalize(NormalTransform * Tangent);
        #endif
    #else
        vNormal = normalize(mat3(infos[gl_InstanceIndex].Normal) * Normal);
        #if HAVE_TANGENT
            vTangent = normalize(mat3(infos[gl_InstanceIndex].Normal) * Tangent);
        #endif
    #endif
#endif

#if HAVE_UV
    vUV = UV;
#endif
}
