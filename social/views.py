# social/views.py
from django.shortcuts import render

#Implement restful API routes to access the posts, comments etc.

def home(request):
    return render(request, 'social/home.html')

