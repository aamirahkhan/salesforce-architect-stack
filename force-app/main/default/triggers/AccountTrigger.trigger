trigger AccountTrigger on Account (before insert, before update) {
    TriggerDispatcher.run(new AccountTriggerHandler());
}
