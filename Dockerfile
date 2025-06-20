# Dockerfile

FROM cirrusci/flutter:3.13.9  # Has Android SDK and Flutter pre-installed

WORKDIR /app

COPY . .

RUN flutter pub get
RUN flutter test
RUN flutter build apk --release  # Optional: build step

CMD ["echo", "Flutter Docker build completed."]
