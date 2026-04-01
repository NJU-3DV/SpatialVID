import requests


def api_call(prompt_text, model, api_key, base_domain):
    """
    Make an API call to a language model with a constructed prompt,
    handling different API formats for different model providers.

    Supported providers:
    - Qwen (DashScope):  set base_domain to 'https://dashscope.aliyuncs.com/'
    - MiniMax:           set base_domain to 'https://api.minimax.io/v1/'
    - Gemini (via proxy): any other base_domain (default: https://cn2us02.opapi.win/)
    """
    # Determine provider based on base_domain
    is_qwen = "dashscope.aliyuncs.com" in base_domain
    is_minimax = "api.minimax.io" in base_domain

    # Configure API endpoint and payload based on model type
    if is_minimax:
        # MiniMax OpenAI-compatible endpoint; temperature must be in (0.0, 1.0]
        api_url = "https://api.minimax.io/v1/chat/completions"
        payload = {
            "model": model,
            "messages": [
                {"role": "user", "content": prompt_text}
            ],
            "temperature": 0.1  # Low temperature for more deterministic output
        }
    elif is_qwen:
        api_url = base_domain + "v1/chat/completions"
        # Payload format specific to Qwen model
        payload = {
            "model": model,
            "messages": [
                # {"role": "system", "content": "You are a helpful assistant."},  # Optional system message
                {"role": "user", "content": prompt_text}
            ],
            "enable_thinking": False,
            "temperature": 0.1  # Low temperature for more deterministic output
        }
    else:
        # Payload format for other models (e.g. Gemini via proxy)
        api_url = base_domain + "v1beta/openai/"
        payload = {
            "model": model,
            "messages": [
                {"role": "user", "content": prompt_text}
            ],
            "temperature": 0.1,
            "user": "User"
        }

    # Configure request headers
    if is_qwen or is_minimax:
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
            "Accept": "application/json"
        }
    else:
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
            "User-Agent": f"({base_domain})",
            "Accept": "application/json"
        }

    try:
        # Execute API request with timeout
        response = requests.post(
            api_url,
            headers=headers,
            json=payload,
            timeout=120  # 2-minute timeout
        )
        response.raise_for_status()  # Raise exception for HTTP errors
        response_data = response.json()

        # Optional: Uncomment to log token usage
        # if 'usage' in response_data:
        #     usage = response_data.get('usage', {})
        #     prompt_tokens = usage.get('prompt_tokens', 0)
        #     completion_tokens = usage.get('completion_tokens', 0)
        #     total_tokens = usage.get('total_tokens', 0)
        #
        #     print(f"Input tokens: {prompt_tokens}")
        #     print(f"Output tokens: {completion_tokens}")
        #     print(f"Total tokens: {total_tokens}")
        # else:
        #     print("API response does not contain token usage information")

        # Extract and return response content
        return response_data.get("choices", [{}])[0].get("message", {}).get("content", "")

    except Exception as e:
        print(f"API request error: {str(e)}")
        return None
