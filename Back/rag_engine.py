import os
from typing import List, Any
from langchain_community.document_loaders import PyMuPDFLoader, DirectoryLoader
from langchain_community.vectorstores import Chroma
from langchain_community.embeddings import SentenceTransformerEmbeddings
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_ollama import ChatOllama
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

class SkinRAG:
    def __init__(
        self,
        persist_dir: str = "chroma_skin_db",
        pdf_dir: str = "skin_docs",  
        embedding_model: str = "all-MiniLM-L6-v2",
        llm_model: str = "qwen2.5:3b"
    ):
        self.persist_dir = os.path.join(BASE_DIR, persist_dir)
        self.pdf_dir = os.path.join(BASE_DIR, pdf_dir)
        
        #  Setup Embeddings
        self.embedding_function = SentenceTransformerEmbeddings(model_name=embedding_model)
        
        #  Initialize/Load Vector Store
        self.vectorstore = self._load_or_build_store()
        
        #  Setup LLM
        self.llm = ChatOllama(model=llm_model, temperature=0.3)
        
        #  Prompt Template
        self.prompt_template = """
You are a professional Skin Care Advisor. 
The AI detector found the following issues: {conditions}
The calculated Severity Score is: {severity}/100.

Answer the user's question using ONLY the provided medical context.
Context:
{context}

Question:
{question}

Guidelines:
1. If severity is high (>60), strongly suggest consulting a dermatologist.
2. Provide clear recommendations based ONLY on the context.
3. If you don't know the answer, recommend seeing a professional.
4. Cite the source document/page if available.
"""
        self.prompt = ChatPromptTemplate.from_template(self.prompt_template)
        self.parser = StrOutputParser()

    def _load_or_build_store(self):
        # Check for existing DB
        if os.path.exists(os.path.join(self.persist_dir, "chroma.sqlite3")):
            print(f"[INFO] Loading existing Skin ChromaDB from {self.persist_dir}")
            return Chroma(persist_directory=self.persist_dir, embedding_function=self.embedding_function)
        
        # Build new one if missing
        print(f"[INFO] Building new Skin Vector Store from {self.pdf_dir}...")
        if not os.path.exists(self.pdf_dir):
            os.makedirs(self.pdf_dir)
            print(f"[WARNING] Created directory {self.pdf_dir}. Please add PDFs and restart.")
            return None

        loader = DirectoryLoader(self.pdf_dir, glob="**/*.pdf", loader_cls=PyMuPDFLoader) #type:ignore
        documents = loader.load()
        
        if not documents:
            print(f"[WARNING] No PDFs found in {self.pdf_dir}")
            return None

        text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
        chunks = text_splitter.split_documents(documents)
        
        return Chroma.from_documents(
            documents=chunks,
            embedding=self.embedding_function,
            persist_directory=self.persist_dir
        )

    def get_response(self, question: str, conditions: List[str], severity: float):
        if not self.vectorstore:
            return "Error: No skin care documents found to provide context."

        query = f"{' '.join(conditions)} {question}"
        retriever = self.vectorstore.as_retriever(search_kwargs={"k": 4})
        docs = retriever.invoke(query)
        context_text = "\n\n".join(d.page_content for d in docs)
        
        chain = self.prompt | self.llm | self.parser
        return chain.invoke({
            "context": context_text,
            "question": question,
            "conditions": ", ".join(conditions) if conditions else "None",
            "severity": severity
        })