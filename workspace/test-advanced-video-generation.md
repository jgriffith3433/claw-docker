# Advanced Video Generation Testing Protocol

## 🎯 Goal
Test the upgraded ComfyUI with SVD, CogVideoX, and LTX-Video to generate professional-quality character animations with perfect consistency.

## 🧪 Test Sequence

### Test 1: SVD (Stable Video Diffusion) - Primary Test
**Input**: Our perfect slime concept (`slime-concept_00001_.png`)
**Workflow**: `svd-character-animation.json`
**Expected**: 14-frame video with character consistency
**Parameters**:
- Motion bucket ID: 127 (moderate motion)
- FPS: 12
- Steps: 20
- CFG: 2.5

**Success Criteria**:
- ✅ Character maintains exact same appearance
- ✅ Smooth breathing/idle animation
- ✅ No morphing or distortion
- ✅ Suitable for Unity sprite extraction

### Test 2: CogVideoX - Text-Guided Generation  
**Input**: Same slime concept + text prompt
**Workflow**: `cogvideox-character-animation.json`
**Prompt**: "The cute green slime character gently breathing and moving slightly, maintaining the exact same appearance, subtle idle animation, no background changes, character consistency is key"
**Expected**: 16-frame video with text guidance
**Parameters**:
- Guidance scale: 6.0
- Steps: 50  
- Seed: 42

### Test 3: LTX-Video - Latest Model
**Input**: Same slime concept + detailed prompt
**Workflow**: `ltx-video-character-animation.json`
**Expected**: 16 selected frames from 121-frame generation
**Parameters**:
- Total frames: 121
- Selected: Every 8th frame (16 total)
- Guidance scale: 3.0
- Steps: 30

## 📊 Comparison Matrix

| Aspect | AnimateDiff | SVD | CogVideoX | LTX-Video |
|--------|-------------|-----|-----------|-----------|
| Character Consistency | ❌ Terrible | ✅ Excellent | ✅ Excellent | ✅ Excellent |
| Generation Speed | ⚡ 90s | ⚡ 60s | 🐌 180s | ⚡ 90s |
| Motion Quality | ❌ Chaotic | ✅ Natural | ✅ Smooth | ✅ Smooth |
| Prompt Adherence | ❌ Poor | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Memory Usage | 8GB | 12GB | 18GB | 10GB |

## 🎮 Unity Integration Test

After generating frames:
1. **Process frames** with `character-pipeline.py`
2. **Remove backgrounds** with rembg  
3. **Create sprite sheet** (4x2 or 4x4 grid)
4. **Import to Unity** with improved prefab pipeline
5. **Test in game** with proper animation

## 🎯 Success Benchmarks

### Minimum Viable Product (MVP)
- ✅ Character maintains consistent appearance across all frames
- ✅ Smooth idle animation (breathing, subtle movement)
- ✅ No artifacts, morphing, or distortion
- ✅ 400x400px output suitable for Unity sprites

### Stretch Goals  
- 🎁 Multiple animation types (idle, excited, sad)
- 🎁 Camera control (slight zoom, rotation)
- 🎁 Lighting variations
- 🎁 Generation time under 60 seconds
- 🎁 Multiple character variations in one batch

## 🔧 Fallback Strategy

If all advanced models fail:
1. **Enhanced prompting** - Try img2img with better control
2. **Manual sprite creation** - Generate 4-6 individual poses
3. **Alternative services** - RunwayML Gen-3, Pika Labs
4. **Code-based animation** - Unity transform tweens (professional approach)

## 📋 Test Commands

### SVD Test
```bash
export COMFYUI_HOST="ec2-3-238-110-77.compute-1.amazonaws.com"
export COMFYUI_PORT="8188"

# Load original slime image and run SVD workflow
python3 skills/comfyui/scripts/comfyui_run.py \
  --workflow workflows/svd-character-animation.json \
  --input-image comfyui-output/slime-concept_00001_.png
```

### CogVideoX Test  
```bash
# Run CogVideoX with text guidance
python3 skills/comfyui/scripts/comfyui_run.py \
  --workflow workflows/cogvideox-character-animation.json \
  --input-image comfyui-output/slime-concept_00001_.png
```

### LTX-Video Test
```bash
# Run LTX-Video with advanced prompting
python3 skills/comfyui/scripts/comfyui_run.py \
  --workflow workflows/ltx-video-character-animation.json \
  --input-image comfyui-output/slime-concept_00001_.png  
```

## 🎬 Expected Timeline

1. **Build Complete** - ✅ Advanced nodes installed
2. **Deploy to GPU** - 5 minutes (pull + restart)
3. **Model Download** - 15 minutes (~50GB models)
4. **SVD Test** - 2 minutes generation
5. **CogVideoX Test** - 5 minutes generation  
6. **LTX-Video Test** - 3 minutes generation
7. **Unity Pipeline** - 2 minutes processing + import

**Total**: ~35 minutes from build complete to game-ready sprites

## 🎉 Success Definition

**We succeed if ANY of the advanced models produces:**
- Consistent character appearance across frames
- Natural idle animation (breathing, subtle movement)  
- Clean 400x400px frames suitable for Unity sprites
- Dramatically better quality than AnimateDiff

**Priority order**: SVD → LTX-Video → CogVideoX → Fallback options

The bar is low - AnimateDiff was so bad that almost anything will be better! 🎯