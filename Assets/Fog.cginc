uniform float _FogDensity;
uniform float3 _FogWorldPosition;
uniform float3 _FogWorldScale;
uniform float3 _LightDir;
#define pi 3.14159265358
float _tri(in float x){return abs(frac(x)-.5);}
float2 _tri2(in float2 p){return float2(_tri(p.x+_tri(p.y*2.)), _tri(p.y+_tri(p.x*2.)));}
float3 _tri3(in float3 p){return float3(_tri(p.z+_tri(p.y*1.)), _tri(p.z+_tri(p.x*1.)), _tri(p.y+_tri(p.x*1.)));}

inline float4 GetCascadeShadowCoord(float4 wpos, fixed4 cascadeWeights)
{
    float3 sc0 = mul(unity_WorldToShadow[0], wpos).xyz;
    float3 sc1 = mul(unity_WorldToShadow[1], wpos).xyz;
    float3 sc2 = mul(unity_WorldToShadow[2], wpos).xyz;
    float3 sc3 = mul(unity_WorldToShadow[3], wpos).xyz;
    
    float4 shadowMapCoordinate = float4(sc0 * cascadeWeights[0] + sc1 * cascadeWeights[1] + sc2 * cascadeWeights[2] + sc3 * cascadeWeights[3], 1);
#if defined(UNITY_REVERSED_Z)
    float  noCascadeWeights = 1 - dot(cascadeWeights, float4(1, 1, 1, 1));
    shadowMapCoordinate.z += noCascadeWeights;
#endif
    return shadowMapCoordinate;
}

fixed4 getCascadeWeights(float z){
			float near = z >= 0.0;
			float far =  z < 10.0;
    float4 zNear = float4( near,near,near,near); 
    float4 zFar = float4( far,far,far,far ); 
    float4 weights = zNear * zFar; 
    
    return weights;
}

//https://www.shadertoy.com/view/4ts3z2 
float TNoise(in float3 p, float time,float spd)
{
    float z=1.4;
    float rz = 0.;
    float3 bp = p;
    //类似FBM 效果 但是指令更少
    for (float i=0.; i<=3.; i++ )
    {
        float3 dg = _tri3(bp*2.);
        p += dg+time*spd;

        bp *= 1.8;
        z *= 1.5;
        p *= 1.2;
        
        rz+= (_tri(p.z+_tri(p.x+_tri(p.y))))/z;
        bp += 0.14;
    }
    return rz;
}

int ihash(int n)
{
	n = (n<<13)^n;
	return (n*(n*n*15731+789221)+1376312589) & 2147483647;
}

float frand(int n)
{
	return ihash(n) / 2147483647.0;
}

float2 cellNoise(int2 p)
{
	int i = p.y*256 + p.x;
	return float2(frand(i), frand(i + 57)) - 0.5;//*2.0-1.0;
}

float getBeerLaw(float density, float stepSize){
    return saturate(exp(-density * stepSize));	
}

fixed4 getShadowCoord(float4 worldPos, float4 weights){
			    float3 shadowCoord = float3(0,0,0);
			    
			    // find which cascades need sampling and then transform the positions to light space using worldtoshadow
			    if(weights[0] == 1){
			        shadowCoord += mul(unity_WorldToShadow[0], worldPos).xyz; 
			    }
			    if(weights[1] == 1){
			        shadowCoord += mul(unity_WorldToShadow[1], worldPos).xyz; 
			    }
			    if(weights[2] == 1){
			        shadowCoord += mul(unity_WorldToShadow[2], worldPos).xyz; 
			    }
			    if(weights[3] == 1){
			        shadowCoord += mul(unity_WorldToShadow[3], worldPos).xyz; 
			    }
			   
                return float4(shadowCoord,1);            
			} 
		

// float sdBox(float3 p, float3 b)
// {
// 	float3 d = abs(p) - b;
// 	return min(max(d.x, max(d.y, d.z)), 0.0) +
// 		length(max(d, 0.0));
// }

// float map(float3 p) {		                                                               
//     float d_box = sdBox(p - float3(_FogWorldPosition), _FogSize);			
//     return d_box;
// }	
float GetDensityBoxFog( float3 p)
{
    float3 q = abs(p - _FogWorldPosition) - _FogWorldScale;
    float d = length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
    float noise = TNoise(p*2.2/(d+20.), _Time.y, 0.2);
    // float noise_mult = fbm(noiseSize * (p + vec3(0.0, 0.0, u_Time * noiseSpeed)));
    // float noise_mult = clamp(snoise(vec4(noiseSize * p, u_Time * noiseSpeed)), 0.0, 1.0);
    // noise_mult = clamp(snoise(vec4(noise_mult));
    // return clamp(-d * noise_mult, 0.0, 1.0);
    return saturate(-d * noise) * 0.5;
}

float3 get_scatter_color(float3 p)
{
    float absorption = 0.0;
    // float2 m = float2(0.4,0.2);
    // float3 light_pos = float3(20.0 * m, 10.0);
    // float3 light_dir = normalize(light_pos - p);
    
    float t = 0.0;
    float rd = 2.5 / 10.0;
    
    for(int i = 0; i < 10; i++)
    {
    	float3 sp = p + t * _LightDir;
        float d = GetDensityBoxFog(sp);
        absorption += d;
    	t+= rd;
    }
    
   
    return saturate(float3(0.8, 0.7, 0.5) * float3(0.4, 0.4, 0.8) - absorption * float3(0.3, 0.4, 0.1));
}

// fixed4 getRayleighPhase(float cosTheta){
//     return (3.0 / (16.0 * pi)) * (1 + (cosTheta * cosTheta));
// }


// float getRayleighScattering(float cosTheta){

//     return getRayleighPhase(cosTheta) * _RayleighScatteringCoef;
// }

// float getScattering(float cosTheta){
    
//     return getRayleighScattering(cosTheta);
// }
UNITY_DECLARE_SHADOWMAP(ShadowMap);
float4 getFog(float3 rayDir, float3 rayOrigin, float depth, float offset)
{
    
    float4 weights = getCascadeWeights(-rayOrigin.z);
    int MAX_SAMPLES_PER_CLUSTER = 16;
    float DIST_BETWEEN_SAMPLES = 0.01;
    float MAX_DIST = 10.0f;
    float3 fogColor = float3(0.0, 0.0, 0.0);
    float density = 0.0;
    int CLUSTER_COUNT_Z = 128;
    float transmittance = 1;
    float stepSize = MAX_DIST / CLUSTER_COUNT_Z;
    float extinction = 0;
    float t = 0.;
    rayOrigin += rayDir * offset;
    
    // float stepSize = rayDistance / CLUSTER_COUNT_Z;
    // NDC is the normalized device coordinates of the quad.
    // fragPos is the view space position of the fragment.
    // float3 farPos = rayOrigin + rayDir * (depth);

    // kNear is a Z in view space. Our ray marching starts from camera's near so initialy it's -cameraNear.
    // It's negative because in OpenGL the camera look vector is the (0,0,-1)
    float kNear = 0.0;
    float kFar = MAX_SAMPLES_PER_CLUSTER * DIST_BETWEEN_SAMPLES;
    [loop]
    for(int k = 0; k < CLUSTER_COUNT_Z; k++)
    {
        // kFar is a Z in view space and it give the far bound of the cluster.
        // kFar = MAX_SAMPLES_PER_CLUSTER * DIST_BETWEEN_SAMPLES * (k + 1);

        // // Compute sample count per cluster
        // float clusterDepth = kNear - kFar;
        // float samplesf = clamp(clusterDepth / DIST_BETWEEN_SAMPLES, 1.0, float(MAX_SAMPLES_PER_CLUSTER));
        // float dist = 1.0 / samplesf;

        // if(transmittance < 0.0000000001){
        //     break;
        // }
        // // float fogDensity = noiseValue * 1.0;
        // extinction = 0.9 * _FogDensity;

        // if(t > MAX_DIST)
        // {
        //     // return float4(0.0,0.0,0.0,1.0);
        //     break;
        // }

        
        // transmittance *= getBeerLaw(extinction, stepSize);
        // float inScattering = getScattering(cosTheta); 
        // inScattering *= _FogDensity;  
        float3 pos = rayOrigin + rayDir * t;// + rayDir * offset * stepSize;
        float3 scatter = get_scatter_color(pos);
        
        float4 shadowCoord = getShadowCoord(float4(pos,1), weights);
        float shadowTerm = UNITY_SAMPLE_SHADOW(ShadowMap, shadowCoord);
        float d = GetDensityBoxFog(pos);
        fogColor += scatter * d;
        density += d;
        t += stepSize; 
        if(t > min(depth, MAX_DIST))
        {
            // return float4(0.0,0.0,0.0,1.0);
            // return (float4(shadowTerm,shadowTerm,shadowTerm, 0.5));
            break;
        }
        // Iterate inside the cluster
        // for(int j = 0; j < uint(samplesf); ++j)
        // {
        //     // // zMedian is the Z in view space of the current sample
        //     float zMedian = kNear + dist * j + dist * offset;

        //     // // Check if the current sample will fall behind the depth
        //     if(zMedian > depth)
        //     {
        //         k = CLUSTER_COUNT_Z; // Break the outer loop
        //         break;
        //     }

        //     // // Compute sample's view space position. The equation is derived by colliding the near plane with 
        //     // // the rayDir
        //     float3 fragPos = rayDir * (zMedian / rayDir.z);

        //     // // Now we have everything, compute the light color of the sample and accumulate
        //     // // lightColor += computeLightColor(fragPos, k);
        //     lightColor += float4(0.02, 0.01, 0.01, 0.03);
        // }

        // kNear = kFar;
    }

    return float4(fogColor, density) * _FogDensity;

    return 1.0;
}