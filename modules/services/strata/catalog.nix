# Pinned Strata-compatible Qwen3.8-Flash-Next files, as upstream Strata
# v0.2.10 setup.py pins them (HF_REVISIONS, ISTA_FILES, UNSLOTH_SHARDS).
# A host picks entries for services.strata.models and adds a port.
let
  ista = quant: {
    url = "https://huggingface.co/ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF/resolve/ed59f92082b1e93c0e96d60a8b11aab089b52f09/${quant}";
    # Shard 2 is the n-gram/PLE table, identical bytes in every ISTA size.
    pleShard = 1;
  };
  istaPle = quant: {
    file = "Qwen3.8-Flash-Next-GSQ-RCO-${quant}-00002-of-00002.gguf";
    sha256 = "316b46f3a2dbd68c900f43136ab9449f9dcc3725dfd8c794847c204bc161e113";
    size = 28800138432;
  };
in
{
  # ISTA-DASLab GSQ-RCO, the original model (Apache-2.0). Upstream's table:
  # Q2_0 fastest/good, IQ2_XS fast/better, IQ3_XXS slower/great, IQ3_S best.
  ista-q2_0 = ista "Q2_0" // {
    shards = [
      {
        file = "Qwen3.8-Flash-Next-GSQ-RCO-Q2_0-00001-of-00002.gguf";
        sha256 = "69820c02ec7d0b45ef2ebb19d6620299db749fe2aded7f39f93c6b88b199b720";
        size = 37623740192;
      }
      (istaPle "Q2_0")
    ];
  };
  ista-iq2_xs = ista "IQ2_XS" // {
    shards = [
      {
        file = "Qwen3.8-Flash-Next-GSQ-RCO-IQ2_XS-00001-of-00002.gguf";
        sha256 = "92cee27ae5bbadcd732416a0f7a7f0acc092399dbbe8f5a5efa707c2ec0a49d7";
        size = 39225954592;
      }
      (istaPle "IQ2_XS")
    ];
  };
  ista-iq3_xxs = ista "IQ3_XXS" // {
    shards = [
      {
        file = "Qwen3.8-Flash-Next-GSQ-RCO-IQ3_XXS-00001-of-00002.gguf";
        sha256 = "219ea929900dfa9ef091f3aa473fdba6874b65fcb36526d7d851ac9e95856d15";
        size = 47039860096;
      }
      (istaPle "IQ3_XXS")
    ];
  };
  ista-iq3_s = ista "IQ3_S" // {
    shards = [
      {
        file = "Qwen3.8-Flash-Next-GSQ-RCO-IQ3_S-00001-of-00002.gguf";
        sha256 = "4c1eb2ceb4915e1192f4f386021897bde56a97f40a0bb78bb86465e0f7d2aca3";
        size = 54817524224;
      }
      (istaPle "IQ3_S")
    ];
  };

  # Unsloth Dynamic 4-bit of the original model. Shard 1 is metadata only;
  # the engine finds the PLE shard itself, as upstream setup leaves it.
  unsloth-ud-q4_k_xl = {
    url = "https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF/resolve/38bb39ee97821de2c9009abb7e93950eec396e66/UD-Q4_K_XL";
    packArgs = [ "--compat-bf16" ];
    shards = [
      {
        file = "Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf";
        sha256 = "4448186216b3af4cc558bbce2c3213f01608f8f8b2e5267a9767971dd3ec8082";
        size = 10946624;
      }
      {
        file = "Qwen3.8-Flash-Next-UD-Q4_K_XL-00002-of-00004.gguf";
        sha256 = "3f342f1c1580473f1ee94ddd5b28206e8c07a70fa1a366f59d1d6c922919a6c9";
        size = 49859583136;
      }
      {
        file = "Qwen3.8-Flash-Next-UD-Q4_K_XL-00003-of-00004.gguf";
        sha256 = "56758f40269cad5cd9b0d3d6fbae0f40f6d5be6de49e4ab392dbe83157d9cbd3";
        size = 49376141504;
      }
      {
        file = "Qwen3.8-Flash-Next-UD-Q4_K_XL-00004-of-00004.gguf";
        sha256 = "753bda48b98ba4f1636134a90a967de1b2d3908a236c026e464777342e53510a";
        size = 12087983520;
      }
    ];
  };
}
