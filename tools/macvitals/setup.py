from setuptools import setup

setup(
    name="macvitals",
    version="1.0.0",
    description="Beautiful macOS System Monitor",
    author="iamsidge",
    python_requires=">=3.10",
    py_modules=["macvitals"],
    install_requires=[
        "customtkinter>=5.2.2",
        "psutil>=5.9.0",
    ],
    entry_points={
        "console_scripts": [
            "macvitals=macvitals:main",
        ],
    },
    classifiers=[
        "Programming Language :: Python :: 3",
        "Operating System :: MacOS",
        "Environment :: MacOS X",
    ],
)
