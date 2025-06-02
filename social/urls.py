from django.urls import path
from . import views  # assuming you have a views.py already

urlpatterns = [
    # Example:
    path('', views.home, name='home'),
]
