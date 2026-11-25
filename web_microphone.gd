extends RefCounted

## Own the browser stream so tab hiding can release tracks even while Godot sleeps.
## The analyser has no speaker connection; only aggregate levels cross the bridge.

const SCRIPT := """
(() => {
    if (window.ASMRDoctorMicrophone) return;
    window.ASMRDoctorMicrophone = class {
        constructor() {
            this.state = "stopped";
            this.error = "";
            this.context = null;
            this.stream = null;
            this.source = null;
            this.analyser = null;
            this.data = null;
            this.frames = 0;
            this.energy = 0;
            this.peak = 0;
            this.rate = 48000;
            this.last = 0;
            this.onBlur = () => this.stop();
            this.onHidden = () => { if (document.hidden) this.stop(); };
        }
        start() {
            this.state = "pending";
            const Context = window.AudioContext || window.webkitAudioContext;
            if (!Context || !navigator.mediaDevices?.getUserMedia) {
                this.fail({name: "NotSupportedError"});
                return;
            }
            try {
                this.context = new Context();
                window.addEventListener("blur", this.onBlur);
                window.addEventListener("pagehide", this.onBlur);
                document.addEventListener("visibilitychange", this.onHidden);
                this.context.resume().catch(error => {
                    if (this.state === "pending" || this.state === "ready") this.fail(error);
                });
                navigator.mediaDevices.getUserMedia({
                    audio: {autoGainControl: false, echoCancellation: false, noiseSuppression: false},
                    video: false
                }).then(stream => {
                    if (this.state !== "pending") {
                        stream.getTracks().forEach(track => track.stop());
                        return;
                    }
                    this.stream = stream;
                    if (document.hidden || !document.hasFocus()) {
                        this.stop();
                        return;
                    }
                    this.source = this.context.createMediaStreamSource(stream);
                    this.analyser = this.context.createAnalyser();
                    this.analyser.fftSize = 2048;
                    this.source.connect(this.analyser);
                    this.data = new Float32Array(this.analyser.fftSize);
                    this.rate = this.context.sampleRate;
                    this.last = this.context.currentTime;
                    this.state = "ready";
                }).catch(error => {
                    if (this.state === "pending" || this.state === "ready") this.fail(error);
                });
            } catch (error) {
                this.fail(error);
            }
        }
        read() {
            this.frames = 0;
            if (this.state !== "ready") return;
            if (!this.stream.active) {
                this.fail({name: "NotReadableError"});
                return;
            }
            if (this.context.state !== "running") return;
            const now = this.context.currentTime;
            this.frames = Math.max(0, Math.round((now - this.last) * this.rate));
            this.last = now;
            if (!this.frames) return;
            this.analyser.getFloatTimeDomainData(this.data);
            let energy = 0;
            let peak = 0;
            for (const sample of this.data) {
                energy += sample * sample;
                peak = Math.max(peak, Math.abs(sample));
            }
            this.energy = energy / this.data.length * this.frames;
            this.peak = peak;
        }
        fail(error) {
            this.error = String(error.name || "Error");
            this.stop();
            this.state = "failed";
        }
        stop() {
            this.state = "stopped";
            window.removeEventListener("blur", this.onBlur);
            window.removeEventListener("pagehide", this.onBlur);
            document.removeEventListener("visibilitychange", this.onHidden);
            if (this.stream) this.stream.getTracks().forEach(track => track.stop());
            if (this.source) this.source.disconnect();
            if (this.analyser) this.analyser.disconnect();
            if (this.data) this.data.fill(0);
            if (this.context && this.context.state !== "closed") {
                this.context.close().catch(error => {
                    console.warn("ASMR Doctor audio context could not close:", error.name);
                });
            }
            this.context = this.stream = this.source = this.analyser = this.data = null;
            this.frames = this.energy = this.peak = 0;
        }
    };
})();
"""


static func create() -> JavaScriptObject:
	JavaScriptBridge.eval(SCRIPT, true)
	return JavaScriptBridge.create_object("ASMRDoctorMicrophone")
