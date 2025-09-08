# app/tools/search_tavily.py
from langchain_tavily import TavilySearch

def get_tavily_tool(max_results: int = 5):
    return TavilySearch(max_results=max_results)
