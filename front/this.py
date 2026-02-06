import streamlit as st
import requests
import base64
from PIL import Image
import io

# --- Configuration ---
FASTAPI_URL = "http://localhost:8000/analyze"

# --- Streamlit Page Configuration ---
st.set_page_config(
    page_title="Skin AI Health Assistant",
    page_icon="✨",
    layout="wide",
    initial_sidebar_state="expanded"
)

# --- Enhanced Custom CSS ---
st.markdown("""
<style>
    .header-container {
        text-align: center;
        margin-bottom: 20px;
    }

    .stApp {
        background-color: #99e2b4;
    }

    h1, h2, h3 {
        color: #1bbfb4 !important;
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    }

    div[data-testid="stWidgetLabel"] p {
        color: grey !important;
        font-weight: bold !important;
    }

    .stImageCaption {
        color: #1bbfb4 !important;
        font-weight: 500 !important;
        text-align: center;
    }

    .stButton>button {
        background-color: #1bbfb4;
        color: white;
        border-radius: 8px;
        border: none;
        padding: 0.5rem 2rem;
        width: 100%;
        font-weight: bold;
        transition: all 0.3s;
    }

    .stButton>button:hover {
        background-color: #159e98;
        border: none;
        color: white;
        transform: scale(1.02);
    }

    .recommendation-box {
        background-color: #1bbfb4;
        color: white;
        padding: 20px;
        border-radius: 10px;
        border-left: 10px solid #159e98;
        margin-top: 20px;
    }

    .condition-badge {
        display: inline-block;
        background-color: #f0fdfc;
        color: #1bbfb4;
        padding: 5px 15px;
        border-radius: 20px;
        border: 1px solid #1bbfb4;
        margin: 5px;
        font-weight: 500;
    }

    .severity-text-header {
        color: #1bbfb4 !important;
        font-weight: bold;
    }

    .severity-container {
        width: 100%;
        background-color: #e0e0e0;
        border-radius: 10px;
        margin: 10px 0;
    }

    .severity-bar {
        height: 20px;
        border-radius: 10px;
        text-align: center;
        color: white;
        font-size: 14px;
        font-weight: bold;
    }
</style>
""", unsafe_allow_html=True)

# --- Header ---
st.markdown("""
<div class="header-container">
    <h1>✨ Skin AI Health Assistant</h1>
    <p style='color: #666;'>Professional Dermatological Analysis Powered by AI</p>
</div>
""", unsafe_allow_html=True)

st.write("---")

# --- Layout ---
col_upload, col_result = st.columns([1, 1], gap="large")

with col_upload:
    st.subheader("📸 Image Upload")
    uploaded_file = st.file_uploader(
        "Drop skin image here",
        type=["jpg", "jpeg", "png"]
    )

    if uploaded_file:
        st.image(uploaded_file, caption="Original Image", use_container_width=True)
        analyze_btn = st.button("Start AI Analysis")

# --- Analysis ---
if uploaded_file and 'analyze_btn' in locals() and analyze_btn:
    with st.spinner("Processing clinical data..."):
        try:
            # ✅ FIX: match FastAPI UploadFile(image)
            files = {
                "image": (
                    uploaded_file.name,
                    uploaded_file.getvalue(),
                    uploaded_file.type
                )
            }

            response = requests.post(
                FASTAPI_URL,
                files=files
            )

            response.raise_for_status()
            result = response.json()

            with col_result:
                st.subheader("🔍 Analysis Results")

                if result.get("annotated_image"):
                    img_bytes = base64.b64decode(result["annotated_image"])
                    st.image(img_bytes, caption="AI Detections", use_container_width=True)

                severity_score = result.get("severity_score", 0)

                if severity_score <= 30:
                    bar_color = "#28a745"
                    label = "Low"
                elif severity_score <= 60:
                    bar_color = "#ff8c00"
                    label = "Moderate"
                else:
                    bar_color = "#dc3545"
                    label = "High"

                st.markdown(f"""
                <div class="severity-text-header">
                    Severity Score: {severity_score}/100 ({label})
                </div>
                """, unsafe_allow_html=True)

                st.markdown(f"""
                <div class="severity-container">
                    <div class="severity-bar"
                         style="width:{severity_score}%; background-color:{bar_color};">
                        {severity_score}%
                    </div>
                </div>
                """, unsafe_allow_html=True)

            st.write("---")
            bottom_col1, bottom_col2 = st.columns([1, 2])

            with bottom_col1:
                st.subheader("🧪 Detected Issues")
                conditions = result.get("detected_conditions", [])
                if conditions:
                    for c in conditions:
                        clean = c.replace("_", " ").title()
                        st.markdown(
                            f'<div class="condition-badge">{clean}</div>',
                            unsafe_allow_html=True
                        )
                else:
                    st.info("No clinical issues detected.")

            with bottom_col2:
                st.subheader("📋 Clinical Recommendation")
                recommendation = result.get(
                    "recommendation",
                    "No specific recommendation available."
                )
                st.markdown(f"""
                <div class="recommendation-box">
                    <h4 style="color:white;margin-top:0;">Personalized Advice</h4>
                    {recommendation}
                </div>
                """, unsafe_allow_html=True)

        except Exception as e:
            st.error(f"Analysis failed: {e}")

elif not uploaded_file:
    with col_result:
        st.info("Waiting for image upload to display results...")

# --- Footer ---
st.markdown(
    "<br><br><p style='text-align:center;color:#aaa;'>"
    "Developed with ❤️ for a healthier skin journey.</p>",
    unsafe_allow_html=True
)
