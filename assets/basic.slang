// This example demonstrates how to define vertex and fragment shader entrypoints.
// This is a compile-only example, so there is no output from the playground.
// You can use the "Compile" button to compile this example to different targets.

struct Vertex
{
    float3 position;
    float3 color;
    float2 uv;
}

struct Matrices
{
    float4x4 model;
    float4x4 view;
    float4x4 proj;
}

ConstantBuffer<Matrices> matrices;

struct VOut
{
    float4 position : SV_Position;
    float3 color;
    float2 uv;
}

[shader("vertex")]
VOut vertexMain(Vertex input)
{
    VOut output;
    output.position = mul(matrices.proj * matrices.view * matrices.model, float4(input.position, 1.0));
    output.color = input.color;
    output.uv = input.uv;
    return output;
}

[shader("fragment")]
float4 fragmentMain(VOut input) : SV_Target
{
    return float4(input.color, 1.0);
}

