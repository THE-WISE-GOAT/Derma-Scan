# Skin Analysis and Recommendation System

An end-to-end AI application that detects visible skin conditions from images and provides recommendations through a chatbot interface using retrieval-augmented generation (RAG).

This project integrates **computer vision, backend APIs, mobile development, and LLM-powered recommendations** into a single deployable system.

---

## Project Architecture

The system consists of four main components:

* Flutter Android application
* FastAPI backend server
* YOLO detection model
* RAG-based chatbot recommendation system

Application flow:

```
Flutter App → FastAPI → YOLO Detection
                          ↓
                        RAG System
                          ↓
                        Chatbot Response
```

A **Streamlit interface** is also included for testing and demonstration.

---

## Features

* Skin condition detection from images
* YOLO object detection model
* FastAPI inference API
* Flutter Android application (APK)
* Retrieval-Augmented Generation recommendation system
* Chatbot interface for explanation and guidance
* Streamlit testing dashboard
* ngrok integration for mobile-backend communication

---

## Tech Stack

### Frontend

* Flutter
* Streamlit

### Backend

* FastAPI
* ngrok

### AI / Machine Learning

* YOLO object detection
* Roboflow dataset preprocessing
* Retrieval-Augmented Generation (RAG)
* Chatbot system

---

## Machine Learning Pipeline

The detection model is trained using a **dermatology image dataset prepared with Roboflow**.
YOLO is used to detect and classify visible skin conditions in uploaded images.

Pipeline:

```
Image → Preprocessing → YOLO Detection → Condition Label
```

The detected condition is then passed to the recommendation system.

---

## Recommendation System (RAG)

The project uses a **Retrieval-Augmented Generation pipeline** to provide skincare recommendations.

Steps:

1. Condition detected by YOLO
2. Relevant documents retrieved from knowledge base
3. Chatbot generates explanation and recommendations

This prevents hallucinated medical advice and keeps responses grounded in stored knowledge.

---

## Running the Backend

Example:

```
uvicorn main:app --reload
```

Expose API:

```
ngrok http 8000
```
