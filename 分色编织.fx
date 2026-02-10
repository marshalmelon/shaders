uniform bool vertical <ui_label="vertical(竖向)";> = false;

#define gammacrt 2.2
#define gammalcd 2.5
#define wh float2(BUFFER_RCP_WIDTH, 0)
#define hw float2(0, BUFFER_RCP_HEIGHT)

texture2D texColor : COLOR;
sampler2D buffer { Texture = texColor; };

texture2D CacheTexX <pooled = true;> { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler2D CacheX { Texture = CacheTexX; };

texture2D CacheTexY <pooled = true;> { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler2D CacheY { Texture = CacheTexY; };

float3 getSameColor(const float3 color, sampler2D tex, const float2 uv, const float2 xy) {
    const float3 colorBefore = tex2D(tex, uv + xy).rgb;
    const float3 colorAfter = tex2D(tex, uv - xy).rgb;
    return (colorBefore + color + colorAfter) / 3;
}

float3 getScanColor(float4 pos, float2 uv, int flag) {
    const float3 color = tex2D(buffer, uv).rgb;
    return pow(color, gammalcd) * 0.43 * float3(flag == 0, flag == 1, flag == 2);
}

float3 getBrightColor(float3 color) {
    return color * saturate(1.34 - 0.15 / color);
}

float3 blur(sampler2D tex, const float2 uv, const float2 xy) {
    const float2 g = xy * 1.6;
    float3 h = tex2D(tex, uv).rgb;
    float weightSum = 1.0;
    const int end = 5 + ((xy.y * vertical || xy.x * !vertical) ? 2 : 0);
    for (int i = 1; i < end; i += 1) {
        float2 j = float(i) * g;
        h += tex2D(tex, uv + j).rgb;
        h += tex2D(tex, uv - j).rgb;
        weightSum += 2.0;
    }
    h /= weightSum;
    return h;
}

void VS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD)
{
    texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

float4 PSX(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    const float3 color = getScanColor(pos, uv, pos.y % 3);
    return float4(getBrightColor(color), 1.0);
}

float4 PSY(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    const float3 color = getScanColor(pos, uv, pos.x % 3);
    return float4(getBrightColor(color), 1.0);
}

float3 getFinalColor(float4 pos, float2 uv, sampler2D tex, int flag, float2 xy, float2 yx) {
    const float3 scanColor = getScanColor(pos, uv, flag);
    const float3 blurColor = blur(tex, uv, xy);
    const float3 sameColor = getSameColor(blurColor, tex, uv, yx);
    const float3 addColor = scanColor + sameColor;
    const float makeMax = pow(240.0 / 255.0, gammacrt) / min(addColor.r, min(addColor.g, addColor.b));
    const float make = min(makeMax, 510.0 / 53.0);
    const float3 phosphorBbloom = addColor * make;
    return pow(phosphorBbloom, 1.0 / gammacrt);
}

float4 PS1(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    return float4(pos.x % 2 == pos.y % 2 ? getFinalColor(pos, uv, CacheX, pos.y % 3, wh, hw) : getFinalColor(pos, uv, CacheY, pos.x % 3, hw, wh), 1.0);
}

technique split_color_weave {
    pass {
        VertexShader = VS;
        PixelShader = PSX;
        RenderTarget = CacheTexX;
    }
    pass {
        VertexShader = VS;
        PixelShader = PSY;
        RenderTarget = CacheTexY;
    }
    pass {
        VertexShader = VS;
        PixelShader = PS1;
    }
}
