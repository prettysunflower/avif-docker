FROM alpine:3.23 AS avif-builder

RUN apk add git cmake yasm clang21 clang21-dev alpine-sdk perl ninja

ENV CC=clang CXX=clang++

RUN git clone -b v1.4.1 --depth 1 https://github.com/AOMediaCodec/libavif.git

WORKDIR /libavif/ext
RUN git clone -b v3.13.3 --depth 1 https://aomedia.googlesource.com/aom 
RUN cmake -G Ninja -S aom -B aom/build.libavif -DBUILD_SHARED_LIBS=OFF -DCONFIG_PIC=1 -DCMAKE_BUILD_TYPE=Release -DENABLE_DOCS=0 -DENABLE_EXAMPLES=0 -DENABLE_TESTDATA=0 -DENABLE_TESTS=0 -DENABLE_TOOLS=0
RUN cmake --build aom/build.libavif --config Release --parallel
RUN git clone -b v3.0.2-B --depth 1 https://github.com/BlueSwordM/svt-av1-psyex.git SVT-AV1

WORKDIR /libavif/ext/SVT-AV1/Build/linux
RUN ./build.sh --native --static --release --enable-lto --no-apps

WORKDIR /libavif/ext/SVT-AV1
RUN mkdir -p include/svt-av1
RUN cp Source/API/*.h include/svt-av1

WORKDIR /libavif
RUN cmake -S . -B build  \
    -DAVIF_CODEC_AOM=LOCAL \
    -DAVIF_CODEC_SVT=LOCAL  \
    -DAVIF_LIBYUV=LOCAL  \
    -DAVIF_LIBSHARPYUV=LOCAL  \
    -DAVIF_JPEG=LOCAL  \
    -DAVIF_ZLIBPNG=LOCAL  \
    -DAVIF_LIBXML2=LOCAL \
    -DAVIF_BUILD_APPS=ON  \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_EXE_LINKER_FLAGS="-static"
RUN cmake --build build --config Release --parallel

FROM cgr.dev/chainguard/static:latest

COPY --from=avif-builder /libavif/build/avifenc /usr/bin/
COPY --from=avif-builder /libavif/build/avifdec /usr/bin/
COPY --from=avif-builder /libavif/build/avifgainmaputil /usr/bin/
COPY --from=avif-builder /libavif/build/libavif.a /lib/

ENTRYPOINT ["/usr/bin/avifenc"]
