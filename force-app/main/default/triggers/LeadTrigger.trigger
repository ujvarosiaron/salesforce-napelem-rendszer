


trigger LeadTrigger on Lead (before insert, before update) {
    LeadScoringHandler.calculateLeadScore(Trigger.new);
}