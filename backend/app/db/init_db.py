from app.db.session import engine, Base
from app.db import models

def init_db():
    Base.metadata.create_all(bind=engine)
    print("Database initialized.")

if __name__ == "__main__":
    init_db()
