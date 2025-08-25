import smtplib
from email.message import EmailMessage

def email_alert(subject, body, to):
    msg = EmailMessage()
    msg.set_content(body)
    msg['subject'] = subject
    msg['to'] = to
    
    user = "alertfloodrisk@gmail.com"
    
   
    msg['from'] = user 
    
    password = "blso hzhi mkvz zhkj"

    server = smtplib.SMTP("smtp.gmail.com", 587)
    
    try:
        server.starttls()
        server.login(user, password)
        server.send_message(msg)
        print("Email sent successfully!")
    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        server.quit()

if __name__ == '__main__':
    email_alert("Hey", "Hello How are you", "alfiyanajqureshi@gmail.com")