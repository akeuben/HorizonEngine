// ---------- Shared Structs ----------

struct Vertex
{
    float3 position;
    float3 color;
    float2 uv;
};

struct Matrices
{
    float4x4 model;
    float4x4 view;
    float4x4 proj;
};

// ---------- Uniform Buffer ----------

ConstantBuffer<Matrices> matrices;

// ---------- Texture & Sampler ----------

Sampler2D texSampler;

// ---------- Vertex Output ----------

struct VSOutput
{
    float4 position : SV_Position;
    float3 color;
    float2 uv;
};

// ---------- Vertex Shader ----------

[shader("vertex")]
VSOutput vertex(Vertex input)
{
    VSOutput output;

    // Compute MVP: proj * view * model
    float4x4 mvp = mul(mul(matrices.proj, matrices.view), matrices.model);
    float4 pos = mul(mvp, float4(input.position, 1.0));

    output.position = pos;
    output.color    = input.color;
    output.uv       = input.uv;

    return output;
}

// ---------- Fragment Shader ----------

[shader("fragment")]
float4 fragment(VSOutput input) : SV_Target
{
    // Sample the texture
    float4 outColor = texSampler.Sample(input.uv);

    // Alpha test
    if (outColor.a <= 0.1)
        discard;

    return outColor;
}

