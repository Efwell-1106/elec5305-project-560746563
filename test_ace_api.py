from gradio_client import Client

client = Client("http://127.0.0.1:7865/")

result = client.predict(
    format="wav",
    audio_duration=30,
    prompt="electronic instrumental music with synthesizer and drums,dark",
    lyrics="[instrumental]",
    infer_step=60,
    guidance_scale=15,
    scheduler_type="euler",
    cfg_type="apg",
    omega_scale=10,

    manual_seeds=12315,

    guidance_interval=0.5,
    guidance_interval_decay=0,
    min_guidance_scale=3,
    use_erg_tag=True,
    use_erg_lyric=False,
    use_erg_diffusion=True,
    oss_steps=None,
    guidance_scale_text=0,
    guidance_scale_lyric=0,
    audio2audio_enable=False,
    ref_audio_strength=0.5,
    ref_audio_input=None,
    lora_name_or_path="none",
    lora_weight=1,
    api_name="/__call__"
)

print("生成完成！")
print(result)