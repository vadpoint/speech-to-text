
# - Де виникатиме найбільша затримка.
# Поки людина розмовляє, затримки немає.
# Потім, коли вона закінчила розмовляти, то в нас буде велика пауза, щоб ми зрозуміли, що вона закінчила.
# Потім ми відправимо все до ЛЛМ. І будемо чекати відповіді ЛЛМ.
# Потім у нас почнеться TTS.
# І це є наша найбільша затримка. Коли людина закінчила розмовляти, і ми почали відповідати. Це і буде.
# Тому що, по-перше, ми чекаємо паузу, щоб зрозуміти, що вона закінчила, а потім в нас дуже багато логіки.
# Має спрацювати одночасно.

# - Як оптимізувати pipeline.
# Я намагався оптимізувати. Там ще можна було б одну логіку винести також в Create Task.
# Я трохи нервую, якщо чесно.
# Оптимізувати — це не чекати, поки людина закінчить розмову,
# А потім не чекати поки LLM поверне весь текст.
# Потім не чекати, не намагатись сформувати весь текст одразу як TTS, а формувати по фразам.

# - Як би виглядала продакшн-архітектура.
# STT Microservice,
# TTS Microservice,
# Interface спілкування з клієнтом Microservice,
# LLM Microservice. База, мабуть, окремий мікросервіс. Це вже як мікросервіс LLM, до нього вже може бути як окремий мікросервіс база.

import asyncio
from asyncio import create_task

END_PHRASE_DELAY = 700  # ms
END_SPEECH_DELAY = 1200


class VoiceBuffer:
    def append(self, chunk):
        pass


# Перевіряє на наявність паузи.
def check_vad(chunk):
    return 0


# якась функція, яка відправляє на розшифровку.
async def process_stt(voice_for_stt, state):
    await asyncio.to_thread(process_stt_worker, voice_for_stt, state)


def stt(voice_for_stt):
    return ""


async def process_stt_worker(voice_for_stt, state):
    # Nen dіlghfdkzєvj d;t pder yf vіrhjcthdіc і xtrfєvj yf hjpibahjdre/
    text = stt(voice_for_stt)
    state.text += " " + text


# Відправляє текст через websocket до ЛЛМ. Повертає чанки зі стрімом. Це також має бути асінхронний генератор.
async def send_text_to_llm(text):
    pass


# Тут відправляємо на LLM і нам треба це робити через мікросервіс та через асінхронний генератор.
async def process_text(state):
    buffer = ""
    async for word in send_text_to_llm(state.text):
        # Треба буферізувати те, що воно відповідає.
        buffer += " " + word
        if word[-1] in [".", "!", "?"]:
            phrase = buffer
            buffer = ""
            yield phrase


# Отримає чанки підготовленого голоса від ТТС.
async def process_tts_worker(phrase):
    return VoiceBuffer()


# Відправляє контент на мікросервіс, який вже спілкується з клієнтом.
async def process_reply(chunk):
    pass


async def process_tts(phrase, state):
    # І потім, коли у нас почне приходити стрім з TTS, відправляти його вже на мікросервіс,
    # на воркер, який безпосередньо відповідає за отримання та передачу голосу.
    async for chunk in process_tts_worker(phrase):
        # І ми почнемо отримувати вже голос і треба буде його відправляти до клієнта.
        await process_reply(chunk)


async def process(stream):
    # Перш за все, треба зробити State Class.
    class State:
        def __init__(self):
            self.voice_buffer = VoiceBuffer()  # Якийсь клас, який відповідає за зберігання голосу.
            self.pause_counter = 0
            self.total_pause_counter = 0
            self.text_buffer = ""
            self.text = ""

    state = State()
    tasks = []
    tasks_tts = []
    async for chunk in stream:
        # Потім додати в буфер.
        state.voice_buffer.append(chunk)
        # Потім зробити верифікацію в vad.
        pause = check_vad(chunk)
        if pause:
            state.pause_counter += pause
            state.total_pause_counter += pause
            if state.total_pause_counter > END_SPEECH_DELAY:
                # Потім, коли людина закінчила розмовляти, відправити весь текст, який є в LLM.
                # Тут, щоб унікнути рейсінгу, треба почекати, поки закінчиться розпізнання останнього буфера.
                await asyncio.gather(*tasks)
                async for phrase in process_text(state):
                    # Потім почати отримувати слова з ЛЛМ.
                    # А потім, коли слова накопляться до речення, відправити речення на TTS.
                    task_tts = create_task(process_tts(phrase, state))
                    tasks_tts.append(task_tts)

            if END_PHRASE_DELAY < state.pause_counter == state.total_pause_counter:
                # Потім відправити це, якщо є довга пауза, відправити це в STT.
                voice_for_stt = state.voice_buffer
                state.voice_buffer = VoiceBuffer()
                state.pause_counter = 0
                task = asyncio.create_task(process_stt(voice_for_stt, state))
                tasks.append(task)
        else:
            state.pause_counter = state.total_pause_counter = 0
