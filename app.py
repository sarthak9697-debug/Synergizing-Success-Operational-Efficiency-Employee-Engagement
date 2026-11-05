import pandas as pd
import plotly.express as px
import streamlit as st

# Page Configuration
st.set_page_config(
    page_title="Business Operations & Revenue Dashboard",
    page_icon="📊",
    layout="wide",
)

st.title("📊 Business Operations & Analytics Portfolio")
st.markdown(
    "Interactive dashboard showcasing SQL data transformations, employee rankings, and department performance metrics."
)


# Load Data (Uses sample data if live DB is not configured)
@st.cache_data
def load_data():
    # Simulated dataset matching your SQL schema for instant portfolio preview
    data = {
        "department": [
            "IT",
            "IT",
            "HR",
            "HR",
            "Sales",
            "Sales",
            "Marketing",
            "Marketing",
            "Accessories",
            "Accessories",
        ],
        "employee_name": [
            "Alice Smith",
            "Bob Jones",
            "Charlie Brown",
            "Diana Prince",
            "Evan Wright",
            "Fiona Gallagher",
            "George Clark",
            "Hannah Abbott",
            "Ian Malcolm",
            "Julia Roberts",
        ],
        "category": [
            "Gadgets",
            "Gadgets",
            "Services",
            "Services",
            "Retail",
            "Retail",
            "Promotions",
            "Promotions",
            "Accessories",
            "Accessories",
        ],
        "revenue": [
            120000,
            95000,
            45000,
            60000,
            210000,
            180000,
            88000,
            92000,
            150000,
            135000,
        ],
        "profit_margin": [22.5, 18.0, 15.2, 14.8, 30.1, 28.5, 12.0, 14.5, 25.0, 22.0],
        "employee_performance_score": [95, 88, 78, 92, 98, 91, 85, 89, 90, 86],
    }
    return pd.DataFrame(data)


df = load_data()

# Sidebar Filters
st.sidebar.header("Filter Controls")
selected_dept = st.sidebar.selectbox(
    "Select Department", options=["All"] + list(df["department"].unique())
)

if selected_dept != "All":
    filtered_df = df[df["department"] == selected_dept]
else:
    filtered_df = df

# Key Metrics Row
col1, col2, col3 = st.columns(3)
col1.metric("Total Revenue", f"${filtered_df['revenue'].sum():,.0f}")
col2.metric(
    "Average Profit Margin", f"{filtered_df['profit_margin'].mean():.2f}%"
)
col3.metric(
    "Avg Performance Score",
    f"{filtered_df['employee_performance_score'].mean():.1f}",
)

st.markdown("---")

# Visualizations using <GenerateWidget> style interactive charts
st.subheader("📈 Revenue by Department")
fig_revenue = px.bar(
    df,
    x="department",
    y="revenue",
    color="department",
    title="Total Revenue Across Departments",
    text_auto=True,
)
st.plotly_chart(fig_revenue, use_container_width=True)

st.subheader("👥 Employee Performance vs Revenue")
fig_scatter = px.scatter(
    df,
    x="employee_performance_score",
    y="revenue",
    color="department",
    hover_name="employee_name",
    title="Employee Performance Score vs. Generated Revenue",
    size_max=15,
)
st.plotly_chart(fig_scatter, use_container_width=True)

# Raw Data Preview
st.subheader("📋 Underlying Dataset View")
st.dataframe(filtered_df, use_container_width=True)