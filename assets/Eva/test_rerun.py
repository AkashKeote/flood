# Test script to verify streamlit rerun functionality
import streamlit as st

st.title("Test Streamlit Rerun")

if st.button("Test Rerun"):
    st.success("Rerun works!")
    st.rerun()

st.write("If this page refreshes when you click the button, st.rerun() is working correctly.")
