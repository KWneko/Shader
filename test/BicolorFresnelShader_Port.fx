

// ------------------------------------------------------ 
// １．変数宣言部分 
// ------------------------------------------------------ 
float4x4 gW : World; 
float4x4 gVP : ViewProjection; 
// ワールドビュープロジェクション行列を取得
float4x4 gWVP   : WorldViewProjection;
float4x4 gVI    : ViewInverse;
float4x4 gWIT   : WorldInverseTranspose;

float3 gLight0Dir : DIRECTION <
    string Object = "Light 0";
    string UIName = "Light 0 Direction"; 
    string Space = "World";
>;

//フレネル反射
uniform float exponent<
    string UIGroup = "Fresnel";
    string UIName = "Exponent";//指数
> = 5.0;

uniform float f0<
    string UIGroup = "Fresnel";
    string UIName = "Base Reflect Fraction";//ベース反射率
> = 0.04;
//

uniform bool gUseNormalColorTexture//チェックボックス
<
    string UIGroup = "Color";
    string UIName = "Use Base Color Texture";
> = false;

uniform float3 gNormalColor
<
    string UIGroup = "Color";
	string UIName = "Base Color";
    string UIWidget="ColorPicker";
> = {0.5, 0.5, 0.5};


//-------------
// Textures
//-------------
// テクスチャファイルを利用するための宣言
uniform Texture2D gNormalColorTexture
<
    string UIGroup = "Color";
    string UIName = "Base Color Texture";
	string UIWidget = "FilePicker";
    string ResourceType = "2D";
>;
// 利用するテクスチャファイルの情報設定
uniform SamplerState gWrapSampler
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
	AddressW = WRAP;
};

//影色
uniform bool gUseshadeColorTexture//チェックボックス
<
    string UIGroup = "Color";
    string UIName = "Use Shadow Color Texture";
> = false;

uniform float3 gShadeColor
<
    string UIGroup = "Color";
	string UIName = "Shadow Color";
	string UIWidget = "ColorPicker";
> = {0.0, 0.0, 0.0};

uniform Texture2D gShadeColorTexture
<
    string UIGroup = "Color";
	string UIName = "Shadow Color Texture";
	string UIWidget = "FilePicker";
	string ResourceType = "2D";
>;

uniform float gToonThreshold<
    string UIGroup = "Color";
    string UIName = "Toon Threshold";
    float UIMin = -1.0;
    float UIMax =  1.0;
> = 0.0;


// ------------------------------------------------------ 
// ２．頂点シェーダー構造体 
// ------------------------------------------------------ 
struct VS_INPUT
{
    //float4 Pos : POSITION;
    float3 Position : POSITION;
    float4 Normal : NORMAL;
    float2 UV : TEXCOORD0;
};

// ------------------------------------------------------ 
// ３．ピクセルシェーダー構造体 
// ------------------------------------------------------ 
struct VS_TO_PS
{
    float4 HPos : SV_Position;
    float4 Normal : NORMAL;
    float2 UV : TEXCOORD0;
    float3 View : TEXCOORD1;
};

// フレネル反射の実装
float schlick_fresnel(float f0, float vdn, float exp)
{
    return f0 + (1.0 - f0) * pow(1.0 - vdn, exp);
}

// ------------------------------------------------------ 
// ４．頂点シェーダーの実装 
// ------------------------------------------------------ 
VS_TO_PS VS(VS_INPUT In) 
{ 
VS_TO_PS Out; 
    float3 worldPos = mul(float4(In.Position, 1), gW).xyz;
    Out.HPos = mul(float4(In.Position, 1), gWVP);
    Out.Normal = mul(In.Normal, gWIT);
    Out.UV = float2(In.UV.x, 1.0 - In.UV.y); //UVを反転して渡す->
//MayaのUV空間とDirectXシェーダーのUV空間はV軸が異なる。
//適切な出力とする為にはHLSLでV軸を反転させる必要がある。
    Out.View = normalize(gVI[3].xyz - worldPos);
return Out; 
} 

// ------------------------------------------------------ 
// ５．ピクセルシェーダーの実装 
// ------------------------------------------------------ 
float4 PS(VS_TO_PS In) : SV_Target 
{ 
    float3 N = In.Normal;
    float3 L = -gLight0Dir;
    // テクスチャの取得と条件分岐
    float3 normalColor;
    float3 shadeColor;
    
    if (gUseNormalColorTexture == true) // 通常色の判定
        normalColor = pow(gNormalColorTexture.Sample(gWrapSampler, In.UV), 2.2);
    else
        normalColor = gNormalColor;

    if (gUseshadeColorTexture == true)  // 影色の判定
        shadeColor = pow(gShadeColorTexture.Sample(gWrapSampler, In.UV), 2.2);
    else
        shadeColor = gShadeColor;

    // ２値化
    float toonShade = step(gToonThreshold, dot(N, L));
    
    // 色指定
    float3 toonColor = lerp(shadeColor, normalColor, toonShade);

    float vdn = max(0.0, dot(In.View, In.Normal));
    float F =  schlick_fresnel(f0, vdn, exponent);
    toonColor = lerp(shadeColor, normalColor, F);

    return float4(toonColor, 1.0);
} 

// ------------------------------------------------------ 
// ６．テクニック宣言部 // （６）頂点シェーダーとピクセルシェーダーをまとめるところ
// ------------------------------------------------------ 
technique11 MoveVertex
{ 
pass P0 // ベースカラー用のパス 
{ 
SetVertexShader(CompileShader(vs_5_0, VS())); 
SetPixelShader(CompileShader(ps_5_0, PS())); 
} 
}

technique11 ColorTexture
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, VS()));
        SetPixelShader(CompileShader(ps_5_0, PS()));
    }
}


technique11 Toon
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, VS()));
        SetPixelShader(CompileShader(ps_5_0, PS()));
    }
}