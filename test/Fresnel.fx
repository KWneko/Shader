

// ------------------------------------------------------ 
// １．変数宣言部分 
// ------------------------------------------------------ 
float4x4 gW : World; 
float4x4 gVP : ViewProjection; 
//uniform float3 gOffsetPosition = {0.0f, 0.0f, 0.0f }; 
// （１）ワールドビュープロジェクション行列を取得するところ
//float4x4 gWVPXf : WorldViewProjection;
float4x4 gWVP   : WorldViewProjection;
float4x4 gVI    : ViewInverse;
float4x4 gWIT   : WorldInverseTranspose;



//フレネル反射
uniform float exponent<
    string UIName = "Exponent";
> = 5.0;

uniform float f0<
    string UIName = "Base Reflect Fraction";
> = 0.04;
//








float3 gLight0Dir : DIRECTION <
    string Object = "Light 0";
    string UIName = "Light 0 Direction"; 
    string Space = "World";
>;


uniform bool gUseNormalColorTexture//（１）bool型アトリビュートの追加:チェックボックス
<
    string UIName = "Use Base Color Texture";
> = false;

//（６）floa3型アトリビュートの追加
//（６）float３型をカラーピッカーウィジェットとして追加
//カラーピッカーウィジェットはよく使います。
//色指定時にカラーピッカーが表示され、値が指定できます。
//uniform float3 color_attr
uniform float3 gNormalColor
<
	string UIName = "Base Color";
    string UIWidget="ColorPicker";//アトリビュートの追加
> = {0.5, 0.5, 0.5};


//-------------
// Textures
//-------------
// （１）テクスチャファイルを利用するための宣言
//uniform Texture2D Texture_Color//Texture2D型とSamplerState型はセットで必要
uniform Texture2D gNormalColorTexture
<
	//int UIOrder = 0;//アトリビュートの表示順序の指定ができる
    string UIName = "Base Color Texture";
	//string UIName = "Color Texture";
	string UIWidget = "FilePicker";//アトリビュートの追加
    string ResourceType = "2D";
>;
// （２）利用するテクスチャファイルの情報設定
//SamplerState Sampler_Wrap
uniform SamplerState gWrapSampler
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
	AddressW = WRAP;
};

//影色
uniform bool gUseshadeColorTexture//（１）bool型アトリビュートの追加:チェックボックス
<
    string UIName = "Use Shadow Color Texture";
> = false;

uniform float3 gShadeColor
<
	string UIName = "Shadow Color";
	string UIWidget = "ColorPicker";//アトリビュートの追加
> = {0.0, 0.0, 0.0};

uniform Texture2D gShadeColorTexture
<
	string UIName = "Shadow Color Texture";
	string UIWidget = "FilePicker";//アトリビュートの追加
	string ResourceType = "2D";
>;

uniform float gToonThreshold<
    string UIName = "Toon Threshold";//アトリビュートの追加
    float UIMin = -1.0;
    float UIMax =  1.0;//最小値、最大値の設定ができる。
> = 0.0;






// ------------------------------------------------------ 
// ２．頂点シェーダー構造体 
// ------------------------------------------------------ 
//struct VS_INPUT { float3 Position : POSITION; }; 
struct VS_INPUT// （２）頂点シェーダーで利用する情報を入れるところ
{
    //float4 Pos : POSITION;
    float3 Position : POSITION;
    float4 Normal : NORMAL;
    float2 UV : TEXCOORD0; // （３）TEXCOORD0＝UV セマンティック(=ポリゴンメッシュが持つ情報)
};


// ------------------------------------------------------ 
// ３．ピクセルシェーダー構造体 
// ------------------------------------------------------ 
//struct VS_TO_PS { float4 HPos : SV_Position; }; 
struct VS_TO_PS// （３）ピクセルシェーダーで利用する情報を入れるところ
{
    float4 HPos : SV_Position;
    float4 Normal : NORMAL;
    float2 UV : TEXCOORD0; //（３）TEXCOORD0＝UV セマンティック
    float3 View : TEXCOORD1;
};



// （１）フレネル反射の実装
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
//float3 worldPosition = mul(float4(In.Position, 1), gW); 
//worldPosition += gOffsetPosition; 
//Out.HPos = mul(float4(worldPosition, 1), gVP); 
    //Out.HPos = mul(In.Pos, gWVPXf);
    float3 worldPos = mul(float4(In.Position, 1), gW).xyz;
    Out.HPos = mul(float4(In.Position, 1), gWVP);
    Out.Normal = mul(In.Normal, gWIT);
    Out.UV = float2(In.UV.x, 1.0 - In.UV.y); //（４）UVを反転して渡す->
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
//return float4(1.0, 0.0, 0.0, 1.0); 
    //（５）サンプラーとUVを使ってテクスチャの色を取得します
//    float4 linear_color = Texture_Color.Sample(Sampler_Wrap, In.UV);
//    float4 sRGB_color = pow(linear_color, 2.2); //（６）ガンマ補正
//    return sRGB_color;

    float3 N = In.Normal;
    float3 L = -gLight0Dir;

    // （１）テクスチャの取得と条件分岐
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

    // （２）２値化
    float toonShade = step(gToonThreshold, dot(N, L));
    
    // （３）色指定
    float3 toonColor = lerp(shadeColor, normalColor, toonShade);
    //return float4(toonColor, 1.0);//作成したアトリビュートを取得し、マテリアルの色を変更


    float vdn = max(0.0, dot(In.View, In.Normal));
    float F =  schlick_fresnel(f0, vdn, exponent);
    return float4(F.xxx, 1.0);// （３）swizzle機能




} 

// ------------------------------------------------------ 
// ６．テクニック宣言部 // （６）頂点シェーダーとピクセルシェーダーをまとめるところ
// ------------------------------------------------------ 
//ここで複数のシェーダを記述すれば切り替えができるようだ
technique11 MoveVertex //シェーダのプロパティエディタ＞テクニック名のタイトルになる
{ 
pass P0 // ベースカラー用のパス 
{ 
SetVertexShader(CompileShader(vs_5_0, VS())); 
SetPixelShader(CompileShader(ps_5_0, PS())); 
} 
}

technique11 ColorTexture//シェーダのプロパティエディタ＞テクニック名のタイトルになる
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, VS()));
        SetPixelShader(CompileShader(ps_5_0, PS()));
    }
}

technique11 Color_attr
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